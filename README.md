# Tool Master

Tool Master, FRP / TTRPG kampanyaları için geliştirilen Android tabanlı bir Dungeon Master / Game Master çalışma alanıdır.

> **Sürüm:** 0.1.3  
> **Durum:** Aktif geliştirme aşamasında  
> **Platform:** Android  
> **Framework:** Flutter  
> **Dil:** Dart  

---

## Geliştirme Durumu

Tool Master şu anda **aktif geliştirme aşamasındadır** ve henüz kararlı `1.0.0` sürümüne ulaşmamıştır.

Bu nedenle geliştirme sürecinde:

- arayüz değişiklikleri,
- yeni özellikler,
- hata düzeltmeleri,
- performans iyileştirmeleri,
- telefon ve tablet düzeninde değişiklikler

yapılabilir.

Kaynak kodu inceleyebilir, kendi ihtiyaçlarınıza göre değiştirebilir ve projeyi kendiniz geliştirebilirsiniz.

---

## Geliştirme Ortamı

Tool Master aşağıdaki ortam kullanılarak geliştirilmiştir:

```text
IDE          : Android Studio Rabbit 2026.2.1
Framework    : Flutter
Dil          : Dart
Platform     : Android
Emülatör     : Medium Phone
Android API  : 37.0
```

Uygulama geliştirme sürecinde **Medium Phone API 37.0** emülatörü üzerinde simüle edilmiş ve test edilmiştir.

Telefon ve tablet görünümü Flutter'ın ekran boyutuna göre çalışan responsive yapı sistemi ile ayrılmıştır.

---

## Uygulamayı Kendiniz Geliştirebilirsiniz

Tool Master kaynak kodunu indirerek kendi sürümünüzü oluşturabilirsiniz.

Projeyi klonlamak için:

```powershell
git clone https://github.com/KULLANICI-ADIN/tool-master.git
cd tool-master
```

Paketleri yüklemek için:

```powershell
flutter pub get
```

Uygulamayı çalıştırmak için:

```powershell
flutter run
```

Temiz çalıştırma için:

```powershell
flutter clean
flutter pub get
flutter run
```

Release APK oluşturmak için:

```powershell
flutter build apk --release
```

APK şu klasörde oluşur:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## Android Güvenlik Uyarısı

Tool Master şu anda **Google Play Store üzerinden yayınlanmamaktadır**.

Uygulamanın APK dosyası manuel olarak kurulmaktadır ve Play Store üzerinden dağıtılan, Google tarafından tanınmış bir yayın sürümü değildir.

Bu nedenle Android veya Google Play Protect bazı cihazlarda uygulamayı:

- bilinmeyen kaynaktan gelen uygulama,
- doğrulanmamış uygulama,
- daha önce tanınmayan uygulama

olarak işaretleyebilir veya kurulum sırasında güvenlik uyarısı gösterebilir.

> Bu uyarı tek başına uygulamanın zararlı yazılım içerdiği anlamına gelmez.

Play Store dışında dağıtılan APK dosyalarında bu tür uyarılar görülebilir.

---

## Güvenlik Testleri

Geliştirme sırasında oluşturulan Tool Master APK dosyası geliştirici tarafından **4 farklı antivirüs / güvenlik uygulamasıyla test edilmiştir**.

Yapılan testlerde zararlı yazılım bildirimi alınmamıştır.

Bununla birlikte hiçbir antivirüs veya güvenlik testi yüzde yüz garanti vermez.

Bu nedenle uygulamanın APK dosyasını yalnızca:

- resmi GitHub deposundan,
- GitHub Releases bölümünden,
- geliştiricinin paylaştığı resmi bağlantılardan

indirmeniz önerilir.

Hazır APK kullanmak istemeyen kullanıcılar kaynak kodu indirerek uygulamayı kendi bilgisayarlarında derleyebilirler.

---

## Kaynak Koddan APK Derleme

Kaynak koddan APK oluşturmak için:

```powershell
flutter clean
flutter pub get
flutter build apk --release
```

Derleme tamamlandığında:

```text
build/app/outputs/flutter-apk/app-release.apk
```

dosyası oluşacaktır.

Bu yöntem sayesinde kullanıcı uygulamayı doğrudan GitHub'daki kaynak koddan kendisi derleyebilir.

---

## Kullanılan Teknolojiler

Tool Master geliştirilirken temel olarak şu teknolojiler kullanılmıştır:

```text
Flutter
Dart
Android Studio
Android SDK
Gradle
Android Emulator
Material 3
```

---

## Proje Dosya Yapısı

```text
tool-master/
│
├── lib/
│   └── main.dart
│
├── assets/
│   ├── branding/
│   │   └── tool_master_logo.png
│   │
│   └── fantasy/
│
├── android/
│   └── app/
│       └── src/
│           └── main/
│
├── pubspec.yaml
├── README.md
└── ...
```

### `lib/main.dart`

Uygulamanın ana Dart kodunu içerir.

Bu dosyada:

- uygulama başlangıcı,
- telefon arayüzü,
- tablet arayüzü,
- tema sistemi,
- kayıt sistemi,
- kasa sistemi,
- JSON sistemi,
- DM araçları,
- savaş araçları,
- wiki link sistemi,
- arama,
- ayarlar

gibi ana sistemler bulunmaktadır.

### `pubspec.yaml`

Flutter projesinin:

- sürümünü,
- bağımlılıklarını,
- asset klasörlerini,
- proje bilgilerini

tanımlar.

### `assets/branding/tool_master_logo.png`

Tool Master uygulama logosudur.

### `assets/fantasy/`

Uygulamada kullanılan FRP / fantasy ikonlarını içerir.

---

## Telefon ve Tablet Desteği

Tool Master cihaz ekranını otomatik olarak algılar.

```text
shortestSide < 600dp   → Telefon arayüzü
shortestSide >= 600dp  → Tablet arayüzü
shortestSide >= 720dp  → Büyük tablet
```

Telefon ve tablet aynı veri sistemini kullanır ancak arayüzleri farklıdır.

---

## Tema Sistemi

Tool Master şu tema modlarını destekler:

```text
Sistem
Karanlık
Aydınlık
```

Ayrıca farklı vurgu renkleri seçilebilir.

Örnek:

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

---

## Proje Durumu

Tool Master halen geliştirilmektedir.

```text
Tool Master
Version 0.1.3
Status: Active Development
```

Yeni sürümlerde özellikler, tasarım ve uygulama mimarisi değişebilir.

---

## Katkıda Bulunma

Projeyi fork ederek kendi değişikliklerinizi yapabilirsiniz.

Önerilen akış:

```text
Fork
↓
Clone
↓
Yeni branch oluştur
↓
Değişiklik yap
↓
Commit
↓
Push
↓
Pull Request
```

Hata bildirimleri ve geliştirme önerileri GitHub Issues üzerinden paylaşılabilir.

---

## Not

Tool Master bağımsız olarak geliştirilen bir projedir ve şu anda Google Play Store üzerinde yayınlanmış resmi bir mağaza sürümü bulunmamaktadır.

APK dosyasını kullanmadan önce kaynağını doğrulamanız ve mümkünse resmi GitHub Releases bölümünden indirmeniz önerilir.
