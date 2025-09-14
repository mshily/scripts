> cat install_nvim.sh 
#!/usr/bin/env bash
set -euo pipefail

# если не root — используем sudo (или просим запустить от root)
SUDO=''
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO='sudo'
  else
    echo "❗ Запусти скрипт от root или установи sudo."
    exit 1
  fi
fi

echo "▶️  Чистим возможные старые ручные установки..."
$SUDO rm -f /usr/local/bin/nvim || true
$SUDO rm -rf /usr/local/nvim-linux64 || true
hash -r || true

echo "▶️  Обновляем индекс пакетов..."
$SUDO apt update

echo "▶️  Ставим утилиты для репозиториев и загрузок..."
$SUDO apt install -y git ninja-build gettext cmake unzip curl build-essential

echo "▶️  клонируем репо»
$SUDO git clone https://github.com/neovim/neovim.git
$SUDO cd neovim

echo "▶️  берем стабильную ветку»
$SUDO git checkout stable

echo «install CMAKE»
$SUDO make CMAKE_BUILD_TYPE=Release
$SUDO make install   

hash -r
echo "▶️  Проверка:"
command -v nvim
nvim --clean +'lua print("ok")' +q
nvim --version | head -5
echo "🎉 Готово. Запускай: nvim"


