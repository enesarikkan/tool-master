# Tool Master

**Tool Master**, FRP / TTRPG kampanyaları için geliştirilen Android tabanlı bir DM / GM çalışma alanıdır.

> **Sürüm:** 0.1.3  
> **Durum:** Aktif geliştirme  
> **Platform:** Android  
> **Framework:** Flutter  
> **Dil:** Dart  

---

## İndirme

GitHub **Releases** bölümünden cihazınıza uygun APK'yı indirin.

**Çoğu modern Android telefon ve tablet için:**

```text
app-arm64-v8a-release.apk
```

Diğerleri:

```text
app-armeabi-v7a-release.apk  → Eski / 32-bit Android cihazlar
app-x86_64-release.apk       → Genellikle Android emülatörleri
```

Emin değilseniz **arm64-v8a** sürümünü indirin.

---

## Neler Var?

Tool Master içinde:

- NPC, Monster, Session, Location, Quest, Item, Organization, Lore, Rule, Journal, Handout ve Template kayıtları
- Wiki link, backlink ve bağlantısız bahsetme sistemi
- Ağ / graph görünümü
- Etiketler, klasörler ve özel alanlar
- Çoklu kasa sistemi
- Arşiv, yer imi ve sabit kayıtlar
- Görev merkezi
- Günlük notlar ve şablonlar
- JSON içe aktarma
- Zar masası
- Initiative ve HP takibi
- Savaş araçları
- Oturum kronometresi ve kampanya araçları
- Telefon ve tablet için ayrı arayüz
- Aydınlık / karanlık / sistem teması
- Farklı vurgu renkleri

bulunur.

---

## Nasıl Geliştirildi?

```text
IDE          : Android Studio Rabbit 2026.2.1
Framework    : Flutter
Dil          : Dart
Android API  : 37.0
Emülatör     : Medium Phone API 37.0
```

Uygulama geliştirme sırasında **Medium Phone API 37.0** emülatörü üzerinde test edilmiştir.

Telefon ve tablet görünümü ekran boyutuna göre otomatik seçilir:

```text
< 600dp   → Telefon
>= 600dp  → Tablet
>= 720dp  → Büyük tablet
```

---

## Proje Dosyaları

```text
tool-master/
├── lib/
│   └── main.dart
├── assets/
│   ├── branding/
│   └── fantasy/
├── android/
├── pubspec.yaml
└── README.md
```

- `lib/main.dart` → uygulamanın ana kodu
- `pubspec.yaml` → sürüm, paketler ve asset ayarları
- `assets/branding/` → logo
- `assets/fantasy/` → FRP ikonları
- `android/` → Android yapılandırmaları ve launcher icon dosyaları

---

## Kullanılan Paketler

Başlıca Flutter paketleri:

```text
file_selector
saf
shared_preferences
cupertino_icons
```

- `file_selector` → dosya seçme
- `saf` → Android klasör / depolama erişimi
- `shared_preferences` → küçük ayarlar ve tercihler

---

## Veriler Nerede Tutuluyor?

Tool Master kullanıcı tarafından seçilen klasör altında kendi veri yapısını oluşturur.

Mevcut teknik klasör adı, eski sürümlerle uyumluluk için:

```text
dmpcsnotebook
```

olarak korunmaktadır.

Temel yapı:

```text
dmpcsnotebook/
├── index.json
├── app_settings.json
└── vaults/
    └── vault_xxx/
        ├── vault.json
        └── backup.json
```

- `index.json` → kasa listesi
- `vault.json` → ana kasa verisi
- `backup.json` → yedek
- `app_settings.json` → bazı uygulama ayarları

---

## Android Güvenlik Uyarısı

Tool Master şu anda **Google Play Store üzerinden dağıtılmamaktadır**.

Bu nedenle Android veya Google Play Protect, manuel kurulan APK için **bilinmeyen / doğrulanmamış uygulama** uyarısı gösterebilir.

Bu uyarı tek başına uygulamanın zararlı olduğu anlamına gelmez.

Geliştirme sırasında APK, geliştirici tarafından **4 farklı antivirüs / güvenlik uygulamasıyla test edilmiş** ve yapılan kontrollerde zararlı yazılım bildirimi alınmamıştır.

Yine de hiçbir güvenlik taraması %100 garanti vermez. APK'yı yalnızca bu projenin resmi **GitHub Releases** bölümünden indirmeniz önerilir.

---

## Kendiniz Geliştirebilirsiniz

Projeyi fork edip kendi sürümünüzü oluşturabilirsiniz.

Çalıştırmak için:

```powershell
flutter clean
flutter pub get
flutter run
```

Release APK oluşturmak için:

```powershell
flutter build apk --release --split-per-abi
```

APK'lar burada oluşur:

```text
build/app/outputs/flutter-apk/
```

---

## Proje Durumu

Tool Master henüz `1.0.0` kararlı sürümüne ulaşmamıştır.

Yeni sürümlerde:

- hata düzeltmeleri,
- yeni özellikler,
- tasarım değişiklikleri,
- performans iyileştirmeleri

yapılabilir.

Hata ve öneriler için GitHub **Issues**, katkılar için **Pull Request** kullanılabilir.
