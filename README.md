# Origins – önálló iOS-platformpróbák

Ez egy önálló UIKit próbaalkalmazás, **nem a játék**. Magyar státuszképernyőt, érintésszámlálót, előtér/háttér életciklust és Metal-eszközjelzést tartalmaz. Játékforrás, asset, szerverkapcsolat, fiók, analitika vagy távoli agent nincs benne.

Ez a nyilvános repó kizárólag saját, játékforrás nélküli iOS-platformpróbákat és kézzel indítható diagnosztikát tartalmaz. A forrás, az Actions-naplók és a megőrzött artifactok nyilvánosak. A fordítás eredménye aláíratlan; Apple-fiók, profil, privát kulcs és signing anyag nem szükséges a CI-futtatáshoz. A grafikai és Python-kísérlet a hivatalos upstream forrást közvetlenül, rögzített commitból tölti le; a játék privát kódját nem használja.

A GitHub dokumentációja szerint nyilvános repóban a standard GitHub-hosted runner használata ingyenes. A workflow-k kizárólag standard ARM64 `macos-26` runnert használnak, kézi `workflow_dispatch` indítással és véges joblimittel; a minimális app limitje 15 perc. A privát repót a jobfeltétel kihagyja; nagyobb vagy fizetős runner nincs beállítva. Az ingyenes lehetőség nem jelent korlátlan kapacitást vagy garantált rendelkezésre állást. Forrás: [GitHub Actions díjazás és használat](https://docs.github.com/en/actions/concepts/billing-and-usage), [standard GitHub-hosted runnerek](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

## A repó teljes forrástartalma

```text
README.md
.github/workflows/ios-probe.yml
.github/workflows/ios-graphics-probe.yml
.github/workflows/ios-python-probe.yml
ios_port/source/ios/probe/main.mm
ios_port/source/ios/probe/Info.plist.in
ios_port/source/ios/probe/CMakeLists.txt
ios_port/source/ios/probe/README.md
ios_port/tools/ios/build_probe.sh
ios_port/tools/ios/build_graphics_probe.sh
ios_port/tools/ios/build_python_probe.sh
ios_port/source/ios/python_probe/abi_probe.c
ios_port/source/ios/python_probe/UPSTREAM.json
ios_port/source/ios/python_probe/README.md
ios_port/source/ios/python_probe/NOTICE
```

A minimális app workflow-ja kizárólag az önálló UIKit-próbát építi. A játék kliens-, szerver- és assetforrása külön projektben marad.

## Kézi futtatás és eredmények

A meglévő Xcode/CMake/iOS SDK-k ellenőrzése után külön ARM64 simulator és device build futna, aláírás nélkül. Nincs csomagtelepítés, Apple-belépés, alkalmazástelepítés vagy appindítás. A device lépés simulatorhiba után is megpróbálható, ha a checkout és a toolchain-előellenőrzés sikerült.

Az eredmények külön app/csomag és bizonyíték artifactokban, **egy napig** maradnának meg. Az `.app` könyvtárakat `tar.gz` őrzi meg a fájljogosultságokkal együtt; a simulatorhoz nincs IPA. A device IPA **aláíratlan, közvetlenül nem telepíthető**. A hash-ek, toolchain, parancsok, nyugták és naplók külön letölthetők; hiba esetén csak a rendelkezésre álló diagnosztika kerülne feltöltésre.

Az [első CI-futás](https://github.com/kecskeslaszlo94/sorin2-origins-ios-probe/actions/runs/42512584859) sikeresen elkészítette az ARM64 simulator és iPhone kimenetet. Az AltServer névhibája után kizárólag az alkalmazás display neve lett ASCII: `Origins iOS Probe`. A [javított build](https://github.com/kecskeslaszlo94/sorin2-origins-ios-probe/actions/runs/42513792832) forrása `03042d4b12333df15309ca6ba567f8cd883b36ef`, Xcode 26.6 és iOS SDK 26.5; mindkét platform sikeres, a CI-kimenet aláíratlan.

A helyi AltServer-újraaláírás és iPhone-os telepítés sikeres; az app jelenlétét az eszköz alkalmazáslistája igazolta. A fejlesztői bizalom helyi jóváhagyása után a felhasználó megerősítette az app megnyitását, a gomb és a háttérből visszatérés működését. Ez a minimális platformpróba eredménye. Metal-renderelés, szimulátoros indulás, aláírásmegújítás és teljes játékos E2E még nincs igazolva; az app csak a Metal-eszköz elérhetőségét kérdezi le.

## Következő, még nem futtatott kompatibilitási kísérletek

- **ANGLE:** a pontos upstream commitból külön ARM64 iOS Simulator és iPhone `libEGL`/`libGLESv2` framework fordításának kísérlete. Aláírás kikapcsolva; GN-argumentumok, dependency-revíziók, teljes napló, tárhely és artifacthash rögzítve. A kézi job legfeljebb 60 percig fut, 10 GiB alatti induló szabad helynél megáll. Nincs teljes Chromium-fallback, fizetős runner vagy rendszereszköz-telepítés. A kandidátus még nincs Macen fordítva; framework-buildből sem következik renderelő app.
- **Python 2.7.18:** saját SDK-típusméret/LLVM-IR diagnosztika, hivatalos pristine upstream host-bootstrap és iOS target-configure kísérlet. A stock konfiguráló Darwin cross-build akadálya ismert; a diagnosztikai eredmény lehet blokkolt, és nem jelent iOS-interpreter-PASS-t. Nincs Android-konfiguráció vagy játékadapter, automatikus patch és saját pyconfig a csomagban. A pontos scope és forráspin a Python-próba README-jében található.

Mindkét kísérlet csak kézzel indítható, standard public `macos-26` runnerrel és read-only repository-jogosultsággal. Az upstream hookok nyilvános fordítási függőségeket tölthetnek le. A korábbi minimális app forrása és sikeres buildje változatlan marad.
