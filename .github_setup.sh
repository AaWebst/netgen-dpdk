#!/bin/bash
# GitHub Repository Setup Script
# Run this after git clone to set up your repository

echo "Setting up NetGen Pro VEP1445 repository..."

# Initialize git (if not already done)
if [ ! -d ".git" ]; then
    git init
    git add .
    git commit -m "Initial commit: NetGen Pro VEP1445 v4.1.0"
fi

echo ""
echo "To push to GitHub:"
echo "  1. Create repository on GitHub"
echo "  2. git remote add origin https://github.com/YOUR_USERNAME/netgen-pro-vep1445.git"
echo "  3. git branch -M main"
echo "  4. git push -u origin main"
echo ""
echo "Repository is ready for GitHub!"
