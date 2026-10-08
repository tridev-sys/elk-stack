# ELK Stack - Production Ready Docker Setup

⚠️ **This repository is actively developed on the `dev` branch.**

## 🔗 Go to the Dev Branch

All code, documentation, and features are on the **dev branch**:

```bash
git clone https://github.com/tridev-sys/elk-stack.git
cd elk-stack
git checkout dev
```

## 🚀 Quick Start

Once on the `dev` branch:

```bash
# Create Docker network
docker network create shared

# Start ELK stack
docker-compose up -d

# Start Nginx proxy
docker-compose -f proxy_server/docker-compose.yml up -d

# Access at http://localhost (admin:admin123)
```

## 📚 Documentation

All documentation is in the `.claude/` folder on the dev branch:

- **`.claude/README.md`** — Complete setup & debugging guide
- **`.claude/LEARNING_ELK.md`** — Comprehensive learning guide (1,300+ lines)
- **`.claude/HOW_ELK_WORKS.md`** — Architecture deep-dive
- **`.claude/TESTING.md`** — Testing procedures
- **`.claude/QUICKSTART.md`** — Quick operations reference
- **`.claude/claude.md`** — Project specification

## 📖 What is ELK?

**ELK Stack** = Elasticsearch + Logstash + Kibana

A production-ready logging and monitoring infrastructure that:

✅ Ingests logs from all your services  
✅ Indexes them for instant search  
✅ Visualizes with beautiful dashboards  
✅ Survives container restarts  
✅ Runs entirely in Docker  

---

## 🎯 What You Get

- Complete Docker setup with docker-compose
- Logstash pipeline for log ingestion
- Nginx reverse proxy with authentication
- 2,000+ lines of documentation
- Automated testing scripts
- Production-ready configuration
- Clear learning path from beginner to advanced

---

## 🔗 Links

- **GitHub (Dev Branch):** https://github.com/tridev-sys/elk-stack/tree/dev
- **GitHub (This Repo):** https://github.com/tridev-sys/elk-stack

---

## 📝 Next Steps

1. **Clone the repo**
   ```bash
   git clone https://github.com/tridev-sys/elk-stack.git
   cd elk-stack
   git checkout dev
   ```

2. **Read the documentation** in `.claude/` folder

3. **Follow the quick start** in `.claude/README.md`

4. **Send logs and explore** Kibana dashboards

---

**Ready?** Switch to the dev branch and get started! 🚀
