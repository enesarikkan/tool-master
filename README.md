# Tool Master

**Tool Master**, FRP / TTRPG kampanyaları için geliştirilmiş bir **Dungeon Master / Game Master çalışma alanı** uygulamasıdır.

Telefon ve tablet için ayrı arayüzlere sahiptir. Aynı kasa ve kayıt sistemi kullanılır; ekran düzeni cihaz boyutuna göre otomatik olarak değişir.

> **Sürüm:** 0.1.3  
> **Platform:** Android  
> **Framework:** Flutter  
> **Dil:** Dart  

---

## Hangi Program ve Teknolojilerle Yapıldı?

### Flutter
Tool Master'ın ana framework'ü **Flutter**'dır.

Kullanılan başlıca Flutter yapıları:
- Material 3
- StatefulWidget
- ChangeNotifier
- InheritedNotifier
- MediaQuery
- LayoutBuilder
- CustomPainter
- AnimationController
- AnimatedContainer
- AnimatedSwitcher
- responsive telefon / tablet layout sistemi

### Dart
Uygulamanın programlama dili **Dart**'tır.

Ana uygulama mantığının büyük bölümü şu dosyadadır:

```text
lib/main.dart
```

Bu dosyada:
- kasa sistemi
- kayıt modelleri
- telefon arayüzü
- tablet arayüzü
- tema sistemi
- DM araçları
- savaş araçları
- JSON işlemleri
- arama
- wiki link sistemi
- görevler
- ayarlar

bulunur.

### Android Studio
Proje Android tarafında **Android Studio** ile çalıştırılabilir ve test edilebilir.

Android Studio üzerinden:
- Android Emulator
- fiziksel Android cihaz
- Logcat
- Gradle
- Android SDK

kullanılabilir.

### Android SDK
Uygulama Android hedeflidir ve Flutter'ın Android build altyapısını kullanır.

```text
Flutter
Dart
Android SDK
Gradle
Android Flutter Embedding
```

---

## Kullanılan Flutter Paketleri

`pubspec.yaml` içinde kullanılan temel paketler:

```yaml
dependencies:
  flutter:
    sdk: flutter

  cupertino_icons: ^1.0.8
  file_selector: ^1.1.0
  saf: ^2.1.2
  shared_preferences: ^2.5.3
```

### file_selector
JSON gibi dosyaların kullanıcı tarafından seçilmesi için kullanılır.

### saf
Android Storage Access Framework desteği için kullanılır. Kullanıcı bir klasör seçebilir ve Tool Master verilerini bu klasör altında tutabilir.

### shared_preferences
Küçük yerel ayarlar ve tercihler için kullanılır.

Örnek:
- tema
- vurgu rengi
- telefon / tablet görünüm tercihi
- tablet çalışma alanı seçenekleri
- bazı hızlı araç tercihleri

---

# Proje Dosya Yapısı

```text
tool_master/
│
├── lib/
│   └── main.dart
│
├── assets/
│   ├── branding/
│   │   └── tool_master_logo.png
│   │
│   └── fantasy/
│       ├── npc.png
│       ├── monster.png
│       ├── item.png
│       ├── location.png
│       ├── quest.png
│       ├── session.png
│       ├── scroll.png
│       ├── organization.png
│       ├── lore.png
│       ├── dice.png
│       └── ...
│
├── android/
│   └── app/
│       └── src/
│           └── main/
│               ├── AndroidManifest.xml
│               └── res/
│                   ├── mipmap-mdpi/
│                   ├── mipmap-hdpi/
│                   ├── mipmap-xhdpi/
│                   ├── mipmap-xxhdpi/
│                   ├── mipmap-xxxhdpi/
│                   └── values/
│
├── pubspec.yaml
├── README.md
└── ...
```

---

# Önemli Dosyalar

## `lib/main.dart`

Projenin ana Dart dosyasıdır.

İçinde:
- uygulama başlangıcı
- tema sistemi
- telefon / tablet algılama
- kasa sistemi
- kayıt modelleri
- kayıt editörü
- DM araçları
- savaş araçları
- JSON sistemi
- ayarlar
- arama
- wiki link sistemi
- backlink sistemi
- graph görünümü

bulunur.

## `pubspec.yaml`

Flutter projesinin ana yapılandırma dosyasıdır.

Burada:
- proje adı
- sürüm
- Dart SDK aralığı
- Flutter paketleri
- asset klasörleri

tanımlanır.

Tool Master sürümü:

```yaml
version: 0.1.3
```

## `assets/branding/tool_master_logo.png`

Tool Master logosunun uygulama içinde kullanılan görselidir.

## `assets/fantasy/`

FRP kayıt türlerinde kullanılan ikon dosyalarını içerir.

Örnek:

```text
npc.png
monster.png
quest.png
location.png
item.png
session.png
dice.png
scroll.png
```

---

# Android Dosyaları

## `AndroidManifest.xml`

Konum:

```text
android/app/src/main/AndroidManifest.xml
```

Android uygulamasının:
- görünen adı
- launcher activity
- launcher icon
- Flutter embedding

ayarlarını içerir.

## Android Uygulama Adı

```text
Tool Master
```

## Launcher Icon

Android launcher ikonları:

```text
android/app/src/main/res/mipmap-mdpi/
android/app/src/main/res/mipmap-hdpi/
android/app/src/main/res/mipmap-xhdpi/
android/app/src/main/res/mipmap-xxhdpi/
android/app/src/main/res/mipmap-xxxhdpi/
```

Ana dosya:

```text
ic_launcher.png
```

Round icon:

```text
ic_launcher_round.png
```

---

# Uygulama Verileri Nerede Saklanıyor?

Tool Master kullanıcıdan Android Storage Access Framework üzerinden bir klasör seçmesini ister.

Mevcut veri uyumluluğu nedeniyle uygulamanın teknik veri klasörü şu anda:

```text
dmpcsnotebook
```

olarak kalmaktadır.

Örnek veri yapısı:

```text
dmpcsnotebook/
│
├── index.json
├── app_settings.json
├── README.txt
│
└── vaults/
    ├── vault_xxxxx/
    │   ├── vault.json
    │   └── backup.json
    │
    └── vault_yyyyy/
        ├── vault.json
        └── backup.json
```

## `index.json`

Kasaların listesini ve aktif kasa bilgisini tutar.

## `vault.json`

Bir kasanın asıl verisini tutar.

Burada:
- kayıtlar
- başlıklar
- içerikler
- türler
- özel alanlar
- klasörler
- etiketler

bulunur.

## `backup.json`

Kasa verisinin yedek kopyasıdır.

## `app_settings.json`

Bazı uygulama ve çalışma alanı ayarlarının kopyasını içerir.

---

# Telefon ve Tablet Algılama

Tool Master cihaz modelinden ziyade gerçek kullanılabilir ekran ölçüsünü kullanır.

```text
shortestSide < 600dp   → Telefon
shortestSide >= 600dp  → Tablet
shortestSide >= 720dp  → Büyük Tablet
```

Bu kontrol:
- uygulama açıldığında
- ekran döndürüldüğünde
- emulator yeniden boyutlandırıldığında

yeniden hesaplanır.

---

# Telefon Arayüzü

Telefon görünümünde:

```text
Merkez
Kasa
Oluştur
Araçlar
Daha
```

alt navigasyonu bulunur.

Telefon arayüzü tablet tasarımının sadece küçültülmüş hali değildir.

Mobil için ayrıca:
- özel Merkez ekranı
- mobil Kasa
- liste / kart görünümü
- mobil filtreler
- bottom-sheet menüler

bulunur.

---

# Tablet Arayüzü

Tablet görünümü daha geniş bir DM çalışma masası olarak tasarlanmıştır.

```text
┌──────────────┬─────────────────────────────┬──────────────────┐
│ Sol Menü     │ Ana Çalışma Alanı           │ Bağlam Rafı      │
│              │                             │                  │
│ Merkez       │ Kasa                        │ Son kayıtlar     │
│ Kasa         │ Editör                      │ Görevler         │
│ Oluştur      │ Ağ                          │ Linkler          │
│ Ağ           │ Araçlar                     │ Kısayollar       │
│ Araçlar      │                             │                  │
│ Ayarlar      │                             │                  │
└──────────────┴─────────────────────────────┴──────────────────┘
```

Tablet özellikleri:
- Geniş / kompakt sol menü
- İki panelli Kasa
- Kayıt önizleme paneli
- Kayıt denetçisi
- Sağ bağlam rafı
- Kompakt / dengeli / ferah yoğunluk

---

# Tema Sistemi

Desteklenen tema modları:

```text
Sistem
Karanlık
Aydınlık
```

Vurgu renkleri:

```text
Arcane Mavi
Menekşe
Derin Turkuaz
Zümrüt
Kehribar
Gül
Kızıl
Arduvaz
```

Tema altyapısı Flutter `ThemeData` ve `ColorScheme` kullanır.

---

# Kayıt Türleri

Desteklenen kayıt türlerinden bazıları:

```text
Not
NPC
Monster
Session
Location
Quest
Item
Organization
Lore
Rule
Journal
Handout
Template
```

---

# Wiki Link Sistemi

Kayıtlar birbirine bağlanabilir:

```markdown
[[Not Başlığı]]
```

Alias:

```markdown
[[Not Başlığı|Görünen Ad]]
```

Desteklenen bağlantı sistemleri:
- giden bağlantılar
- geri bağlantılar
- çözülemeyen bağlantılar
- bağlantısız bahsetmeler
- ilişkili kayıtlar
- graph

---

# JSON Veri Merkezi

Tool Master harici JSON verilerini içeri aktarabilir.

Tanıyabildiği yaygın alanlardan bazıları:

```text
title
name
ad
isim
başlık

content
body
description
text
notes

type
kind
category
tür

tags
labels
etiketler

folder
path
klasör
```

Tanımlanamayan alanlar özel alan olarak alınabilir.

---

# DM Araçları

Tool Master içinde masa sırasında kullanılabilecek çeşitli araçlar vardır.

## Zar Masası

```text
d4
d6
d8
d10
d12
d20
d100
```

Ayrıca:
- çoklu zar
- modifier
- zar geçmişi

bulunur.

## Initiative / HP

- initiative sıralaması
- round takibi
- aktif sıra
- HP
- maksimum HP

## Savaş Paneli+

- HP
- geçici HP
- AC
- condition
- ölüm kurtarışları
- konsantrasyon
- slot / kaynak
- hızlı hasar
- hızlı iyileştirme
- round notları
- savaş özeti

## Oturum Araçları

- kronometre
- geri sayım
- lap
- sahne kuyruğu
- spotlight
- kaynak sayaçları
- yorgunluk
- ilham
- yazı-tura
- rastgele sayı
- d100

---

# Diğer Önemli Özellikler

- Çoklu kasa
- Etiketler
- Klasörler
- Özel alanlar
- Görev Merkezi
- Sabit kayıtlar
- Yer imleri
- Arşiv
- Günlük not
- Şablonlar
- JSON import
- Yedekleme
- Kasa analizi
- Toplu işlemler
- Yazım Laboratuvarı
- Üretkenlik Merkezi+
- İstatistikler+
- Hızlı İşlemler+
- Ağ görünümü
- Tablo
- Pano

---

# Uygulamayı Çalıştırma

Flutter kurulumunu kontrol edin:

```powershell
flutter doctor
```

Paketleri yükleyin:

```powershell
flutter pub get
```

Uygulamayı çalıştırın:

```powershell
flutter run
```

Temiz çalıştırma:

```powershell
flutter clean
flutter pub get
flutter run
```

---

# Release APK Oluşturma

```powershell
flutter build apk --release
```

APK şu klasörde oluşur:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Dosya daha sonra örneğin:

```text
Tool-Master-v0.1.3.apk
```

olarak yeniden adlandırılabilir.

## Daha küçük ABI APK'ları

```powershell
flutter build apk --release --split-per-abi
```

---

# Ekran Görüntüleri

GitHub deposunda örneğin:

```text
screenshots/
├── phone-home.png
├── phone-more.png
├── tablet-home.png
├── tablet-vault.png
├── light-theme.png
└── dark-theme.png
```

kullanılabilir.

README içine:

```markdown
![Telefon Ana Ekran](screenshots/phone-home.png)
```

şeklinde eklenebilir.

---

# Bilinen Sınırlamalar

- Projenin ana Dart kodunun büyük bölümü halen `lib/main.dart` içindedir.
- Bazı masa araçlarının geçici değerleri uygulama kapanınca saklanmayabilir.
- Proje şu anda Android odaklıdır.
- Bulut senkronizasyonu henüz temel sürümün parçası değildir.
- Teknik veri klasör adı eski sürümlerle uyumluluk için `dmpcsnotebook` olarak kalmaktadır.

---

# Proje Durumu

```text
Tool Master
Version 0.1.3
Status: Active Development
```

Tool Master henüz `1.0.0 stable` sürümüne ulaşmamıştır.

---

# Gelecek İçin Planlanabilecekler

- Kod tabanını daha küçük Dart dosyalarına ayırmak
- Yerel veritabanı
- Bulut senkronizasyonu
- Hesap sistemi
- DM / Player rolleri
- Kampanya paylaşımı
- Ortak çalışma
- Görsel/dosya ekleri
- PDF export
- Markdown export
- Masaüstü sürümü
- Web sürümü

---

## Geliştirici Notu

Tool Master, **Flutter + Dart + Android SDK** kullanılarak geliştirilen Android odaklı bir FRP kampanya ve DM çalışma alanıdır.
