# CPython 2.7.18 Apple SDK diagnostic

Önálló, upstream-only kompatibilitási próba. Nincs benne játékforrás,
Android adapter, előre gyártott pyconfig, patch vagy signing anyag.
A hivatalos commit/tree pin az `UPSTREAM.json` fájlban található.

```bash
bash tools/ios/build_python_probe.sh --run-id manual-001
```

macOS, teljes Xcode, mindkét iOS SDK, Apple Clang, Git, Make, plutil és
shasum szükséges. A script semmit nem telepít. A munkagyökérben a jelen
könyvtár négy fájlja, a script és a workflow helyi sablonja vagy kanonikus
publikus példánya legyen elérhető.
A `--run-id` csak betűt, számot, pontot, kötőjelet és aláhúzást tartalmazhat;
új futáshoz új azonosító kell. Létező kimenet nem írható felül.

A sorrend:

1. Device **és** simulator SDK-makrók és C11 típusméret/alignment LLVM-IR,
   egyik cél hibája sem akadályozza a másik megpróbálását. Az IR nem futtatás.
2. A hivatalos CPython commit lekérése, HEAD/tree/patcheletlenség ellenőrzés.
3. Pristine natív macOS host configure, `make python Parser/pgen`, minimális
   verzió/codec smoke. Az explicit `PYTHONPATH=<upstream>/Lib` csak a host
   standard libraryhoz kell; nincs játék-Python, pip vagy site-packages.
4. Ha a host működik, pristine ARM64 iPhoneOS cross configure. A stock
   Linux/Cygwin whitelist várható Darwin akadályát `expected-blocked` címke
   és **2-es kilépési kód** jelöli. Más hiba 1-es kódot kap. Az esetleges
   configure-siker 0-val fejeződhet be, de ez sem interpreter-build/futás.

A mai Apple Clanggel a host bootstrap sincs előre igazoltnak tekintve.
A script nem változtat flageket vagy pyconfigot hiba esetén. Mindig az első
tényleges hibát és a hozzá tartozó nyers logot kell áttekinteni.

Kimenet: `build/python_probe/<run-id>/`. A `publish/` kizárólag a script
statikus engedélylistáján szereplő naplók, ABI-IR/makrók, licence és nyugták
másolata. A `ARTIFACTS.sha256` minden feltöltött payloadot hashel önmaga
kivételével. A host Python, libek, teljes checkout és buildfa nem artifact.
A `RECEIPT.json` minden esetben `ios_interpreter_pass: false` értéket ad.

Minden végrehajtott parancsnak külön teljes stdout/stderr logja és
exit-status sora van; nincs hibaeltüntető tee pipeline. A before/after
forráshash és az upstream pristine státusz is a nyugta része. A script
EXIT trapje megszakadt futásnál is megpróbálja elkészíteni a diagnosztikát;
a runner kényszerleállítása esetén teljes nyugta nem garantálható.

A `tools/ios/github-actions-python-probe.yml` sablont külön felülvizsgálat
után lehet `.github/workflows/ios-python-probe.yml` útvonalra tükrözni. Kizárólag
kézi indítás, standard `macos-26`, 20 perc, `contents: read`, rögzített action
commitek és egynapos artifact-megőrzés. A várt stock akadály is hibás jobként
marad látható; az `always()` feltöltési lépés őrzi meg az eredményt.
Nincs cache, secret, sudo, brew, pip, signing vagy automatikus publikálás.

A publikus csomag összesen hat fájl: a négy probe-fájl, a buildscript és a
kanonikus `.github/workflows/ios-python-probe.yml`; a tools alatti workflow
sablon nem kerül mellé duplán. A script a helyi template vagy a kanonikus
publikus workflow meglévő fix útvonalát hasheli. A helyi felmérési/work
könyvtárak nem publikálási bemenetek.
A CPython nyilvános licence nem ad engedélyt projektkód publikálására.

Bizonyítékhatárok: SDK ABI-fordítás, host bootstrap, target configure,
iOS interpreter-link és valódi készülékes futás külön kapu. Ez a csomag
az első háromhoz gyűjt diagnosztikát; az utolsó kettőt nem végzi el.
