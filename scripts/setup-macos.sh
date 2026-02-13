#!/usr/bin/env bash
set -e

echo "🚀 Setting up blog development environment for macOS..."

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found. Please install from https://brew.sh"
    exit 1
fi

echo "✅ Homebrew found"

# Install ImageMagick (required for Vix/Mogrify)
if ! command -v magick &> /dev/null; then
    echo "📦 Installing ImageMagick..."
    brew install imagemagick
else
    echo "✅ ImageMagick already installed"
fi

# Install Node.js (required for mermaid-cli and puppeteer)
if ! command -v node &> /dev/null; then
    echo "📦 Installing Node.js..."
    brew install node
else
    echo "✅ Node.js already installed ($(node --version))"
fi

# Install mermaid-cli (for diagram generation)
if ! command -v mmdc &> /dev/null; then
    echo "📦 Installing mermaid-cli..."
    npm install -g @mermaid-js/mermaid-cli
else
    echo "✅ mermaid-cli already installed"
fi

# Install Elixir dependencies
echo "📦 Installing Elixir dependencies..."
mix deps.get

# Install npm dependencies
echo "📦 Installing npm dependencies..."
cd assets && npm install --legacy-peer-deps && cd ..

echo ""
echo "✅ Setup complete!"
echo ""
echo "📝 Next steps:"
echo "  1. Create .env file with GITHUB_API_TOKEN"
echo "  2. Run 'mix phx.server' to start the development server"
echo "  3. Visit http://localhost:4000"
