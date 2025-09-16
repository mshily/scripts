#!/usr/bin/env bash
set -euo pipefail

# sudo helper
SUDO=''
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO='sudo'
  else
    echo "❗ Запусти скрипт от root или установи sudo."
    exit 1
  fi
fi

# Кого настраиваем (важно, если запускаешь через sudo)
if [ "$(id -u)" -eq 0 ]; then
  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    TARGET_USER="$SUDO_USER"
    TARGET_HOME="$(eval echo "~$SUDO_USER")"
  else
    TARGET_USER="root"
    TARGET_HOME="/root"
  fi
else
  TARGET_USER="$(id -un)"
  TARGET_HOME="$HOME"
fi

echo "▶️  Чистим возможные старые ручные установки..."
$SUDO rm -f /usr/local/bin/nvim || true
$SUDO rm -rf /usr/local/nvim-linux64 || true
hash -r || true

echo "▶️  Обновляем индекс пакетов..."
$SUDO apt update

echo "▶️  Ставим зависимости для сборки и работы..."
$SUDO apt install -y git ninja-build gettext cmake unzip curl build-essential \
  ripgrep fd-find clangd bear

# На Ubuntu fd называется fdfind — делаем удобный алиас
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  echo "▶️  Создаю symlink: fdfind → fd"
  $SUDO ln -sf "$(command -v fdfind)" /usr/local/bin/fd
fi

echo "▶️  Клонируем репозиторий Neovim и собираем stable..."
tmpdir="$(mktemp -d -t nvim-src-XXXXXX)"
git clone --depth=1 --branch stable https://github.com/neovim/neovim.git "$tmpdir/neovim"
pushd "$tmpdir/neovim" >/dev/null
make CMAKE_BUILD_TYPE=Release
$SUDO make install
popd >/dev/null
rm -rf "$tmpdir"

hash -r
echo "▶️  Проверка:"
command -v nvim
nvim --clean +'lua print("ok")' +q
nvim --version | head -5

echo "▶️  Пишу конфиг в $TARGET_HOME/.config/nvim/init.lua ..."
mkdir -p "$TARGET_HOME/.config/nvim"
cat > "$TARGET_HOME/.config/nvim/init.lua" <<'EOF'
-- ~/.config/nvim/init.lua
-- bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git","clone","--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- список плагинов + ленивая загрузка
require("lazy").setup({
  -- Поиск
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = "Telescope",
    keys = {
      { "<leader>ff", function() require("telescope.builtin").find_files() end, desc="Find files" },
      { "<leader>fg", function() require("telescope.builtin").live_grep()  end, desc="Live grep"  },
    },
  },
  -- Подсветка/парсер (после открытия файла)
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate", event = "BufReadPost" },

  -- LSP/линтеры/форматтеры через Mason (внешние бинарники ставятся отдельно)
  { "williamboman/mason.nvim", config = true, cmd = "Mason" },
  { "neovim/nvim-lspconfig",  event = "BufReadPre" },

  -- Статус-бар и тема (пример)
  { "nvim-lualine/lualine.nvim", event = "VeryLazy", config = true },
  { "catppuccin/nvim", name = "catppuccin", lazy = false, priority = 1000 },
})

-- Базовые опции (по желанию)
vim.o.termguicolors = true
pcall(vim.cmd.colorscheme, "catppuccin")

vim.opt.number = true 
vim.opt.relativenumber = true
vim.opt.cursorline = true

vim.opt.tabstop     = 4   -- ширина существующего \t на экране
vim.opt.shiftwidth  = 4   -- на сколько сдвигать при << и >>
vim.opt.softtabstop = 4   -- сколько вставлять/удалять при Tab/Backspace
vim.opt.expandtab   = true-- Tab -> пробелы (обычно так и нужно)
EOF

# если скрипт шёл от root — отдадим владельца назад пользователю
if [ "$(id -u)" -eq 0 ] && [ "$TARGET_USER" != "root" ]; then
  chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/.config/nvim"
fi

echo "▶️  Предзагрузка плагинов (Lazy sync)..."
sudo -u "$TARGET_USER" nvim --headless "+Lazy! sync" +qa || true

echo "🎉 Готово. Запускай: nvim"
echo "ℹ️  Telescope уже работает (есть ripgrep/fd). LSP: clangd установлен пакетом 'clangd'. Открой .c/.cpp и проверь :LspInfo."

