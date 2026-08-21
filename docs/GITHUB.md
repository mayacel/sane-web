# Publishing on GitHub

Before the first public push:

1. Read `assets/wallpapers/README.md` and confirm redistribution rights for all
   three images.
2. Replace `YOUR-USER` in the README clone example.
3. Run:

```bash
make validate
```

4. Initialize and push:

```bash
git init
git add .
git commit -m "Initial Sane dwl rice"
git branch -M main
git remote add origin git@github.com:YOUR-USER/sane-dwl-rice.git
git push -u origin main
```

The GitHub Actions workflow performs syntax/invariant validation and a source
compile smoke test for the patched dwl/dwlb configuration inside Arch Linux.
