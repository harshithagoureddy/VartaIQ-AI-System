#!/bin/bash

# =====================================
# VartaIQ Production Server Setup Script
# =====================================
# This script prepares a fresh Ubuntu server for VartaIQ deployment
# 
# Usage:
#   1. Copy this script to your server: scp server-setup.sh user@server:/tmp/
#   2. SSH into your server: ssh user@server
#   3. Run the script: bash /tmp/server-setup.sh
#
# Tested on: Ubuntu 20.04, 22.04, 24.04

set -e  # Exit on any error

echo "=========================================="
echo "VartaIQ Production Server Setup"
echo "=========================================="
echo ""

# =====================================
# Check if running as root
# =====================================
if [ "$EUID" -eq 0 ]; then 
    echo "⚠️  Please do not run this script as root"
    echo "Run as a regular user with sudo privileges"
    exit 1
fi

# =====================================
# Update system packages
# =====================================
echo "📦 Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# =====================================
# Install Docker
# =====================================
echo ""
echo "🐳 Installing Docker..."

# Check if Docker is already installed
if command -v docker &> /dev/null; then
    echo "✅ Docker is already installed ($(docker --version))"
else
    # Install prerequisites
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # Set up Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Add current user to docker group
    sudo usermod -aG docker $USER

    echo "✅ Docker installed successfully"
    echo "⚠️  You need to log out and log back in for group changes to take effect"
fi

# =====================================
# Create application directory
# =====================================
echo ""
echo "📁 Creating application directory..."

APP_DIR="$HOME/vartaiq-app"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

echo "✅ Application directory created at: $APP_DIR"

# =====================================
# Create .env file template
# =====================================
echo ""
echo "📝 Creating .env file template..."

if [ -f .env ]; then
    echo "⚠️  .env file already exists. Backing up to .env.backup"
    cp .env .env.backup
fi

cat > .env << 'EOF'
# =====================================
# VartaIQ Production Environment Variables
# =====================================
# IMPORTANT: Replace these placeholder values with your actual credentials

# Database Configuration (Neon PostgreSQL)
DATABASE_URL=postgresql://username:password@your-neon-host.aws.neon.tech/database-name

# HuggingFace API Token
HF_API_TOKEN=hf_your_huggingface_token_here

# Application Configuration
LOG_LEVEL=INFO
ENVIRONMENT=production
EOF

chmod 600 .env

echo "✅ .env file created at: $APP_DIR/.env"
echo "⚠️  IMPORTANT: Edit this file and add your actual credentials!"
echo "   Run: nano $APP_DIR/.env"

# =====================================
# Configure firewall (UFW)
# =====================================
echo ""
echo "🔥 Configuring firewall..."

if command -v ufw &> /dev/null; then
    # Allow SSH (important - don't lock yourself out!)
    sudo ufw allow 22/tcp
    
    # Allow HTTP and HTTPS (if using Nginx)
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    
    # Allow port 8000 (FastAPI)
    sudo ufw allow 8000/tcp
    
    # Enable firewall
    sudo ufw --force enable
    
    echo "✅ Firewall configured"
    sudo ufw status
else
    echo "⚠️  UFW not found. Skipping firewall configuration."
fi

# =====================================
# Install useful tools
# =====================================
echo ""
echo "🛠️  Installing useful tools..."

sudo apt-get install -y \
    htop \
    curl \
    wget \
    git \
    vim \
    nano \
    net-tools

echo "✅ Tools installed"

# =====================================
# Set up log rotation
# =====================================
echo ""
echo "📋 Setting up log rotation for Docker..."

sudo tee /etc/logrotate.d/docker > /dev/null << 'EOF'
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    missingok
    delaycompress
    copytruncate
}
EOF

echo "✅ Log rotation configured"

# =====================================
# Create deployment script
# =====================================
echo ""
echo "📜 Creating deployment helper script..."

cat > "$APP_DIR/deploy.sh" << 'EOF'
#!/bin/bash
# Quick deployment script for VartaIQ

set -e

DOCKER_USERNAME="${1:-your-dockerhub-username}"
IMAGE_NAME="vartaiq-ai-analyzer"
CONTAINER_NAME="vartaiq-ai-analyzer"

echo "🚀 Deploying VartaIQ..."

# Pull latest image
echo "📥 Pulling latest image..."
docker pull "$DOCKER_USERNAME/$IMAGE_NAME:latest"

# Stop and remove old container
echo "🛑 Stopping old container..."
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm $CONTAINER_NAME 2>/dev/null || true

# Start new container
echo "▶️  Starting new container..."
docker run -d \
  --name $CONTAINER_NAME \
  --restart unless-stopped \
  -p 8000:8000 \
  --env-file .env \
  "$DOCKER_USERNAME/$IMAGE_NAME:latest"

# Wait for container to start
echo "⏳ Waiting for container to start..."
sleep 10

# Check health
echo "🏥 Checking health..."
if curl -f http://localhost:8000/health; then
    echo ""
    echo "✅ Deployment successful!"
else
    echo ""
    echo "❌ Health check failed"
    echo "Check logs: docker logs $CONTAINER_NAME"
    exit 1
fi

# Clean up old images
echo "🧹 Cleaning up old images..."
docker image prune -af --filter "until=24h"

echo ""
echo "🎉 Deployment complete!"
echo "Application is running at http://localhost:8000"
EOF

chmod +x "$APP_DIR/deploy.sh"

echo "✅ Deployment script created at: $APP_DIR/deploy.sh"

# =====================================
# Create monitoring script
# =====================================
echo ""
echo "📊 Creating monitoring script..."

cat > "$APP_DIR/monitor.sh" << 'EOF'
#!/bin/bash
# Monitoring script for VartaIQ

CONTAINER_NAME="vartaiq-ai-analyzer"

echo "=========================================="
echo "VartaIQ Container Status"
echo "=========================================="
echo ""

# Check if container is running
if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
    echo "✅ Container is running"
    echo ""
    
    # Show container stats
    echo "📊 Container Stats:"
    docker stats --no-stream $CONTAINER_NAME
    echo ""
    
    # Show recent logs
    echo "📋 Recent Logs (last 20 lines):"
    docker logs --tail 20 $CONTAINER_NAME
    echo ""
    
    # Check health endpoint
    echo "🏥 Health Check:"
    curl -s http://localhost:8000/health | python3 -m json.tool || echo "❌ Health check failed"
    
else
    echo "❌ Container is not running"
    echo ""
    echo "To start the container, run:"
    echo "  cd ~/vartaiq-app && ./deploy.sh your-dockerhub-username"
fi

echo ""
echo "=========================================="
EOF

chmod +x "$APP_DIR/monitor.sh"

echo "✅ Monitoring script created at: $APP_DIR/monitor.sh"

# =====================================
# Summary
# =====================================
echo ""
echo "=========================================="
echo "✅ Server setup complete!"
echo "=========================================="
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Edit the .env file with your actual credentials:"
echo "   nano $APP_DIR/.env"
echo ""
echo "2. Add your SSH public key to ~/.ssh/authorized_keys for GitHub Actions"
echo ""
echo "3. Test Docker (you may need to log out and back in first):"
echo "   docker --version"
echo ""
echo "4. Push to GitHub main branch to trigger automatic deployment"
echo ""
echo "5. Or manually deploy using:"
echo "   cd $APP_DIR && ./deploy.sh your-dockerhub-username"
echo ""
echo "6. Monitor the application:"
echo "   cd $APP_DIR && ./monitor.sh"
echo ""
echo "📚 Useful Commands:"
echo "   docker ps                          # List running containers"
echo "   docker logs -f vartaiq-ai-analyzer # Follow logs"
echo "   docker restart vartaiq-ai-analyzer # Restart container"
echo "   docker stop vartaiq-ai-analyzer    # Stop container"
echo ""
echo "🌐 Access Points:"
echo "   Health: http://$(curl -s ifconfig.me):8000/health"
echo "   API Docs: http://$(curl -s ifconfig.me):8000/docs"
echo ""
echo "=========================================="

# =====================================
# Check if logout is needed
# =====================================
if ! groups | grep -q docker; then
    echo ""
    echo "⚠️  IMPORTANT: Log out and log back in for Docker group changes to take effect"
    echo "   Run: exit"
    echo "   Then SSH back in"
fi
