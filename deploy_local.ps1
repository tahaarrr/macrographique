# Script de déploiement local — Macrographique
# Exécuter depuis la racine du projet : .\deploy_local.ps1
#
# Ce script :
# 1. Build la version Web de Flutter
# 2. Prépare le dossier de déploiement (landing page + app web)
# 3. Affiche les instructions pour déployer sur GitHub Pages

param(
    [string]$BaseHref = "/macrographique/"
)

Write-Host ""
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Macrographique — Script de Build & Déploiement" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# 1. Build Flutter Web
Write-Host "[1/4] 🔨 Build Flutter Web..." -ForegroundColor Yellow
flutter build web --release --base-href "${BaseHref}app/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur lors du build Flutter Web !" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Build Flutter Web terminé." -ForegroundColor Green

# 2. Build APK Android
Write-Host ""
Write-Host "[2/4] 📱 Build APK Android..." -ForegroundColor Yellow
flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ APK généré : build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
} else {
    Write-Host "⚠️ Build APK échoué (besoin d'Android SDK). Continuons..." -ForegroundColor DarkYellow
}

# 3. Préparer le dossier de déploiement
Write-Host ""
Write-Host "[3/4] 📦 Préparation du dossier de déploiement..." -ForegroundColor Yellow

$deployDir = "deploy"
if (Test-Path $deployDir) { Remove-Item $deployDir -Recurse -Force }
New-Item -ItemType Directory -Path $deployDir -Force | Out-Null

# Copier la landing page
Copy-Item -Path "landing-page\*" -Destination $deployDir -Recurse -Force

# Copier l'app Flutter Web
$appDir = "$deployDir\app"
New-Item -ItemType Directory -Path $appDir -Force | Out-Null
Copy-Item -Path "build\web\*" -Destination $appDir -Recurse -Force

Write-Host "✅ Dossier de déploiement prêt : .\$deployDir\" -ForegroundColor Green

# 4. Résumé
Write-Host ""
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  ✅ BUILD TERMINÉ !" -ForegroundColor Green
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Contenu du dossier deploy/ :" -ForegroundColor White
Get-ChildItem $deployDir -Recurse -Depth 1 | Select-Object Name, Length | Format-Table -AutoSize
Write-Host ""
Write-Host "📋 PROCHAINES ÉTAPES :" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Créer un repo GitHub : 'macrographique'" -ForegroundColor White
Write-Host "     git init" -ForegroundColor Gray
Write-Host "     git add ." -ForegroundColor Gray
Write-Host "     git commit -m 'Initial release v1.2.2'" -ForegroundColor Gray
Write-Host "     git remote add origin https://github.com/ayati-tahar/macrographique.git" -ForegroundColor Gray
Write-Host "     git push -u origin main" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Activer GitHub Pages :" -ForegroundColor White
Write-Host "     Settings → Pages → Source: GitHub Actions" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Le workflow .github/workflows/deploy.yml se lancera automatiquement" -ForegroundColor White
Write-Host ""
Write-Host "  4. Votre site sera disponible à :" -ForegroundColor White
Write-Host "     🌐 https://ayati-tahar.github.io/macrographique/" -ForegroundColor Cyan
Write-Host "     📱 https://ayati-tahar.github.io/macrographique/app/" -ForegroundColor Cyan
Write-Host ""
Write-Host "  5. Pour les releases (APK, Setup Windows) :" -ForegroundColor White
Write-Host "     git tag v1.2.2" -ForegroundColor Gray
Write-Host "     git push origin v1.2.2" -ForegroundColor Gray
Write-Host ""

