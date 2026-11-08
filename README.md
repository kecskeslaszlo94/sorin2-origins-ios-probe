# Origins – saját minimális iOS-próba

Ez egy önálló UIKit próbaalkalmazás, **nem a játék**. Magyar státuszképernyőt, érintésszámlálót, előtér/háttér életciklust és Metal-eszközjelzést tartalmaz. Játékforrás, asset, szerverkapcsolat, fiók, analitika vagy távoli agent nincs benne.

Ez a nyilvános repó kizárólag az első önálló iOS-próba forrását és kézzel indítható buildfolyamatát tartalmazza. A forrás, az Actions-naplók és a megőrzött artifactok nyilvánosak. A fordítás eredménye aláíratlan; Apple-fiók, profil, privát kulcs és signing anyag nem szükséges a CI-futtatáshoz.

A GitHub dokumentációja szerint nyilvános repóban a standard GitHub-hosted runner használata ingyenes. A terv kizárólag standard ARM64 `macos-26` runnert használ, kézi `workflow_dispatch` indítással és 15 perces joblimittel. A privát repót a jobfeltétel kihagyja; nagyobb vagy fizetős runner nincs beállítva. Az ingyenes lehetőség nem jelent korlátlan kapacitást vagy garantált rendelkezésre állást. Forrás: [GitHub Actions díjazás és használat](https://docs.github.com/en/actions/concepts/billing-and-usage), [standard GitHub-hosted runnerek](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

## A repó teljes forrástartalma

```text
README.md
.github/workflows/ios-probe.yml
ios_port/source/ios/probe/main.mm
ios_port/source/ios/probe/Info.plist.in
ios_port/source/ios/probe/CMakeLists.txt
ios_port/source/ios/probe/README.md
ios_port/tools/ios/build_probe.sh
```

A workflow kizárólag ezt az önálló próbaappot építi. A játék kliens-, szerver- és assetforrása külön projektben marad.

## Kézi futtatás és eredmények

A meglévő Xcode/CMake/iOS SDK-k ellenőrzése után külön ARM64 simulator és device build futna, aláírás nélkül. Nincs csomagtelepítés, Apple-belépés, alkalmazástelepítés vagy appindítás. A device lépés simulatorhiba után is megpróbálható, ha a checkout és a toolchain-előellenőrzés sikerült.

Az eredmények külön app/csomag és bizonyíték artifactokban, **egy napig** maradnának meg. Az `.app` könyvtárakat `tar.gz` őrzi meg a fájljogosultságokkal együtt; a simulatorhoz nincs IPA. A device IPA **aláíratlan, közvetlenül nem telepíthető**. A hash-ek, toolchain, parancsok, nyugták és naplók külön letölthetők; hiba esetén csak a rendelkezésre álló diagnosztika kerülne feltöltésre.

Az [első CI-futás](https://github.com/kecskeslaszlo94/sorin2-origins-ios-probe/actions/runs/42512584859) sikeresen elkészítette az ARM64 simulator és iPhone kimenetet. Az AltServer névhibája után kizárólag az alkalmazás display neve lett ASCII: `Origins iOS Probe`. A [javított build](https://github.com/kecskeslaszlo94/sorin2-origins-ios-probe/actions/runs/42513792832) forrása `03042d4b12333df15309ca6ba567f8cd883b36ef`, Xcode 26.6 és iOS SDK 26.5; mindkét platform sikeres, a CI-kimenet aláíratlan.

A helyi AltServer-újraaláírás és iPhone-os telepítés sikeres; az app jelenlétét az eszköz alkalmazáslistája igazolta. A fejlesztői bizalom helyi jóváhagyása után a felhasználó megerősítette az app megnyitását, a gomb és a háttérből visszatérés működését. Ez a minimális platformpróba eredménye. Metal-renderelés, szimulátoros indulás, aláírásmegújítás és teljes játékos E2E még nincs igazolva; az app csak a Metal-eszköz elérhetőségét kérdezi le.
