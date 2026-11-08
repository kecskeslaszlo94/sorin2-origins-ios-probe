# Origins – minimális iOS-próba

Önálló UIKit Objective-C++ alkalmazás, játékkód vagy asset importja nélkül. Magyar státuszképernyő, érintésszámláló, előtér/háttér életciklus és a Metal eszköz elérhetőségének kijelzése. A Metal-jelzés nem renderelési, ANGLE- vagy teljesítményteszt.

Bundle ID: `eu.sorin2.origins.iosprobe`. Minimum iOS: **15.0**. ARC, safe-area és nagyobb rendszerszöveget támogató görgethető elrendezés. A plist egyetlen `ProbeSceneDelegate` scene-t konfigurál; az ablak `UIWindowScene`-hez kapcsolódik. Az indulás, aktív/inaktív állapot, háttér és visszatérés scene callbackeken halad. A kezdeti előtérbe lépés nem számít háttérből visszatérésnek. Nincs hálózat, fiók, analitika, jogosultságkérés, háttérszolgáltatás vagy távoli bridge. A számlálók csak a folyamat memóriájában élnek.

## Használat egy később ellenőrzött Macen

Teljes Xcode aktív fejlesztői könyvtárral, iOS/iOS Simulator SDK és CMake 3.24+ szükséges. A projektgyökérből:

```bash
bash tools/ios/build_probe.sh --help
bash tools/ios/build_probe.sh simulator
bash tools/ios/build_probe.sh device
```

A két cél mindig ARM64, Release, külön Xcode buildfával: `build/<UTC-dátum>_minimal_probe/simulator/` és `device/`. A simulator ARM64 Apple Silicon környezethez készül. A script nem indít szimulátort, és nem telepít semmit. Új próba más kijelölt dátummal kérhető: `device --date 20261109`; meglévő kimenetet nem ír felül. Sikertelen kimenetet is megőriz felülvizsgálatra. Nincs automatikus törlés.

A simulator eredménye `.app`, IPA nélkül. A device eredménye **aláíratlan** `.app` és `OriginsIOSProbe-unsigned.ipa`; közvetlenül nem telepíthető. Későbbi AltStore-újraaláírás bemeneti jelöltje lehet, de annak kompatibilitása és telepítése még nincs igazolva. A script nem kezel Apple-belépést, profilt, privát kulcsot, entitlementet vagy signing szolgáltatást.

Minden tényleges buildhez forráslista+SHA-256, toolchain, SDK, teljes parancsok, nyers buildnapló, artifacthash-ek és siker/hiba nyugta tartozik. Sikeres buildnyugta csak létrejött bundle, ellenőrzött azonosító/minimum OS/ARM64, hiányzó signing anyag és változatlan forrásbemenet után készül. A csomagolás nem futtatási bizonyíték. Windows alatt a súgó használható Git Bashből, tényleges build egyértelmű hibával megáll.

## Macen és iPhone-on még nyitott

1. Apple Clang/Xcode fordítás és a renderelt plist ellenőrzése.
2. ARM64 szimulátoron indulás, olvashatóság, gomb, forgatás/nagyobb szöveg, háttérből visszatérés. Csak a háttérből előtérbe lépés növeli a visszatérésszámlálót; például egy értesítési megszakítás önmagában nem.
3. Külön jóváhagyott aláírás/újraaláírás, saját iPhone-os telepítés és ugyanez a készülékes próba. Háttérből visszatérve a számláló megmarad, ha az iOS a folyamatot nem zárta le; új folyamat nulláról indul.

**Windowsos előkészítés, valódi iOS-fordítás és futás nélkül.** Ez a forrás nem állítja a játékkliens iOS-kompatibilitását. Eltávolításhoz csak az új öt forrás/script fájl használható a helyi előkészítési nyugta hash-egyezése és későbbi munka ellenőrzése után; más projektfájl nem érintett.
