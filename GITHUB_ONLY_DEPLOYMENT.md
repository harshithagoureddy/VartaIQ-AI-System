# 🚀 VartaIQ Deployment - GitHub Only (No Docker Hub)

This guide shows you how to deploy using **GitHub Container Registry** instead of Docker Hub.  
Everything stays within GitHub - simpler and free!

---

## 🎯 What Changed

### ❌ Before (Docker Hub)
- Needed Docker Hub account
- Needed Docker Hub token
- Image stored at: `docker.io/harshitha2709/vartaiq`

### ✅ Now (GitHub Container Registry)
- No Docker Hub needed!
- Uses GitHub Personal Access Token
- Image stored at: `ghcr.io/YOUR_GITHUB_USERNAME/vartaiq-ai-system`

---

## 📋 Required GitHub Secrets (5 Total)

You need to add these secrets to your GitHub repository:

### 1. DOCKER_USERNAME
**Value:** Your GitHub username (e.g., `harshitha2709`)

### 2. DOCKER_TOKEN
**Value:** GitHub Personal Access Token (PAT) with `write:packages` permission

**How to create:**
1. Go to https://github.com/settings/tokens
2. Click **"Generate new token"** → **"Generate new token (classic)"**
3. Fill in:
   - **Note:** `VartaIQ CI/CD`
   - **Expiration:** 90 days (or No expiration)
   - **Select scopes:**
     - ✅ `write:packages` (Upload packages to GitHub Package Registry)
     - ✅ `read:packages` (Download packages from GitHub Package Registry)
     - ✅ `delete:packages` (Delete packages from GitHub Package Registry)
4. Click **"Generate token"**
5. **COPY THE TOKEN IMMEDIATELY** (you won't see it again!)
   - It looks like: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

### 3. SERVER_HOST
**Value:** Your EC2 private IP address (e.g., `172.31.32.87`)

### 4. SERVER_USER
**Value:** `ec2-user`

### 5. SSH_PRIVATE_KEY
**Value:** Entire content of your `vartaiq-key.pem` file

**How to get it:**
```powershell
# On Windows PowerShell
type "C:\Users\Admin\Desktop\VartaIQ-AI-System\vartaiq-key.pem"
```

Copy **EVERYTHING** including:
```
-----BEGIN RSA PRIVATE KEY-----
... all the lines ...
-----END RSA PRIVATE KEY-----
```

---

## 🔧 Step-by-Step Setup

### Step 1: Create GitHub Personal Access Token

1. Go to https://github.com/settings/tokens
2. Click **"Generate new token"** → **"Generate new token (classic)"**
3. Settings:
   - Note: `VartaIQ CI/CD`
   - Expiration: `90 days` or `No expiration`
   - Scopes: Check these boxes:
     - ✅ `write:packages`
     - ✅ `read:packages`
     - ✅ `delete:packages`
4. Click **"Generate token"**
5. **COPY THE TOKEN** (starts with `ghp_`)

---

### Step 2: Add Secrets to GitHub Repository

1. Go to your GitHub repository
2. Click **Settings** (top right)
3. In left sidebar: **Secrets and variables** → **Actions**
4. Click **"New repository secret"**

Add each secret:

#### Secret 1: DOCKER_USERNAME
```
Name: DOCKER_USERNAME
Value: harshitha2709
```
(Replace with your actual GitHub username)

#### Secret 2: DOCKER_TOKEN
```
Name: DOCKER_TOKEN
Value: ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```
(Paste the GitHub Personal Access Token you just created)

#### Secret 3: SERVER_HOST
```
Name: SERVER_HOST
Value: 172.31.32.87
```
(Replace with your actual EC2 private IP)

#### Secret 4: SERVER_USER
```
Name: SERVER_USER
Value: ec2-user
```

#### Secret 5: SSH_PRIVATE_KEY
```
Name: SSH_PRIVATE_KEY
Value: (Paste entire vartaiq-key.pem content)
```

---

### Step 3: Make GitHub Container Registry Package Public (Optional)

By default, GitHub Container Registry packages are private. To make it easier to pull:

1. After first deployment, go to your GitHub profile
2. Click **"Packages"** tab
3. Find `vartaiq-ai-system` package
4. Click on it
5. Click **"Package settings"** (right sidebar)
6. Scroll down to **"Danger Zone"**
7. Click **"Change visibility"** → **"Public"**

**Note:** If you keep it private, you'll need to authenticate when pulling (which the workflow already does).

---

### Step 4: Set Up EC2 Server

SSH into your EC2 instance:

```powershell
# From Windows PowerShell
ssh -i "vartaiq-key.pem" ec2-user@YOUR_EC2_IP
```

Install Docker (if not already installed):

```bash
# Update system
sudo yum update -y

# Install Docker
sudo yum install -y docker

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add ec2-user to docker group
sudo usermod -aG docker ec2-user

# Log out and back in
exit
```

Log back in:
```powershell
ssh -i "vartaiq-key.pem" ec2-user@YOUR_EC2_IP
```

Create application directory and .env file:

```bash
# Create directory
mkdir -p ~/vartaiq-app
cd ~/vartaiq-app

# Create .env file
nano .env
```

Paste your environment variables:
```env
DATABASE_URL=postgresql://your-username:your-password@your-neon-host/your-database
HF_API_TOKEN=hf_your_token_here
LOG_LEVEL=INFO
ENVIRONMENT=production
```

Save: `Ctrl+X`, `Y`, `Enter`

Set permissions:
```bash
chmod 600 .env
```

---

### Step 5: Deploy!

```powershell
# On your Windows machine
cd C:\Users\Admin\Desktop\VartaIQ-AI-System

git add .
git commit -m "Switch to GitHub Container Registry"
git push origin main
```

Go to GitHub → **Actions** tab to watch the deployment!

---

## 🎉 What Happens Now

```
1. You push code to GitHub
   ↓
2. GitHub Actions runs (CI stage)
   - Lints code
   - Runs tests
   ↓
3. GitHub Actions builds Docker image
   ↓
4. Image pushed to GitHub Container Registry
   - Location: ghcr.io/YOUR_USERNAME/vartaiq-ai-system:latest
   ↓
5. GitHub Actions SSHs to EC2
   ↓
6. EC2 pulls image from GitHub Container Registry
   ↓
7. EC2 runs the container
   ↓
8. Your app is LIVE! 🎉
```

---

## 📦 Where Is Your Docker Image?

**Before (Docker Hub):**
```
docker.io/harshitha2709/vartaiq:latest
```

**Now (GitHub Container Registry):**
```
ghcr.io/harshitha2709/vartaiq-ai-system:latest
```

You can view it at:
```
https://github.com/YOUR_USERNAME/vartaiq-ai-system/pkgs/container/vartaiq-ai-system
```

---

## 🔍 Verify Deployment

### Check GitHub Actions
1. Go to GitHub → **Actions** tab
2. You should see a green checkmark ✅

### Check EC2
```bash
# SSH into EC2
ssh -i "vartaiq-key.pem" ec2-user@YOUR_EC2_IP

# Check container is running
docker ps

# Check logs
docker logs vartaiq-ai-analyzer

# Test health endpoint
curl http://localhost:8000/health
```

### Access Your App
```
http://YOUR_EC2_IP:8000/health
http://YOUR_EC2_IP:8000/docs
```

---

## 🆚 Comparison: Docker Hub vs GitHub Container Registry

| Feature | Docker Hub | GitHub Container Registry |
|---------|------------|---------------------------|
| **Account needed** | Separate Docker Hub account | Use existing GitHub account |
| **Token** | Docker Hub token | GitHub Personal Access Token |
| **Free tier** | 200 pulls/6 hours | Unlimited for public repos |
| **Private images** | 1 free private repo | Unlimited private repos |
| **Integration** | Separate service | Built into GitHub |
| **Image location** | docker.io/username/image | ghcr.io/username/repo |

---

## 🔐 Security Notes

### GitHub Personal Access Token
- ✅ Can be revoked anytime at https://github.com/settings/tokens
- ✅ Can set expiration date
- ✅ Limited to specific permissions (write:packages)
- ⚠️ Treat it like a password - never commit to code

### SSH Private Key
- ✅ Stored securely in GitHub Secrets
- ✅ Never exposed in logs
- ⚠️ Keep your local .pem file safe

---

## 🛠️ Troubleshooting

### Error: "Permission denied while trying to connect to Docker daemon"
**Solution:** Make sure you logged out and back in after adding user to docker group:
```bash
exit
ssh -i "vartaiq-key.pem" ec2-user@YOUR_EC2_IP
```

### Error: "denied: permission_denied"
**Solution:** Make sure your GitHub Personal Access Token has `write:packages` permission.

### Error: "Failed to pull image"
**Solution:** 
1. Check that DOCKER_USERNAME matches your GitHub username
2. Check that DOCKER_TOKEN is a valid GitHub PAT
3. Make sure the package exists (run deployment once first)

---

## 📊 Summary

### Required Secrets (Same Names as Before!)

| Secret Name | Value | Where to Get It |
|-------------|-------|-----------------|
| **DOCKER_USERNAME** | Your GitHub username | Your GitHub profile |
| **DOCKER_TOKEN** | GitHub Personal Access Token | https://github.com/settings/tokens |
| **SERVER_HOST** | EC2 private IP | AWS EC2 console |
| **SERVER_USER** | `ec2-user` | - |
| **SSH_PRIVATE_KEY** | Content of vartaiq-key.pem | Your local file |

### Key Changes
- ✅ No Docker Hub account needed
- ✅ Uses GitHub Container Registry (ghcr.io)
- ✅ Same secret names (DOCKER_USERNAME, DOCKER_TOKEN)
- ✅ DOCKER_TOKEN is now a GitHub PAT instead of Docker Hub token
- ✅ Everything stays within GitHub ecosystem

---

## 🎯 Next Steps

1. ✅ Create GitHub Personal Access Token
2. ✅ Add 5 secrets to GitHub repository
3. ✅ Set up EC2 with Docker and .env file
4. ✅ Push to main branch
5. ✅ Watch deployment in GitHub Actions
6. ✅ Access your app at `http://YOUR_EC2_IP:8000`

---

**You're all set! Everything now runs through GitHub - no Docker Hub needed! 🚀**
