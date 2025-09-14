echo "✅ SETUP RUSTUP"
curl https://sh.rustup.rs -sSf | sh

echo "✅ SETUP RUST"
source "$HOME/.cargo/env"

echo "✅ CHECK VERSIONS"
rustc -V
cargo -V
rustup -V
