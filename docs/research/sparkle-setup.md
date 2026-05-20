# Звіт R6: Інфраструктура Авто-оновлень через Sparkle 2

Для розповсюдження додатку Smart File Sorter v2.0 поза Mac App Store ми налаштували систему безпечних автоматичних оновлень на базі фреймворку **Sparkle 2**.

---

## 🔑 Безпека та EdDSA Підписи (Ed25519)

Sparkle 2 вимагає обов'язкового підпису оновлень за допомогою алгоритму **EdDSA (Ed25519)**.

### Процес налаштування:
1. **Генерація ключів**:
   Виконується локально розробником за допомогою комплектної утиліти Sparkle:
   ```bash
   ./bin/generate_keys
   ```
   Утиліта згенерує публічний ключ (виводиться на екран) та приватний ключ (автоматично зберігається у macOS Keychain).
2. **Інтеграція в додаток**:
   Публічний ключ додається в файл `Info.plist` додатку:
   ```xml
   <key>SUPublicEDKey</key>
   <string>СЮДИ_ВСТАВИТИ_ПУБЛІЧНИЙ_ЕД_КЛЮЧ</string>
   ```
3. **Захист Приватного Ключа**:
   Приватний ключ **НІКОЛИ** не коммітиться в Git. Для автоматизації CI/CD (GitHub Actions) приватний ключ експортується та додається до Secrets репозиторію під назвою `SPARKLE_PRIVATE_KEY`.

---

## 📡 Структура Флуду Оновлень (Appcast.xml)

Файл `appcast.xml` хоститься на GitHub Pages за адресою:  
`https://slavashootit.github.io/smart-file-sorter/appcast.xml`

### Шаблон конфігурації для двох каналів (Stable + Beta):

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"  xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Smart File Sorter Updates</title>
    <link>https://slavashootit.github.io/smart-file-sorter/appcast.xml</link>
    <description>Most recent updates for Smart File Sorter.</description>
    <language>uk</language>
    
    <!-- СТАБІЛЬНИЙ КАНАЛ (Stable release) -->
    <item>
      <title>Версія 2.0.0 (Мажорний реліз)</title>
      <description><![CDATA[
        <h2>Smart File Sorter v2.0 "Liquid Glass"</h2>
        <ul>
          <li>Новий дизайн Tahoe Liquid Glass.</li>
          <li>Візуалізатор диску Sunburst (DaisyDisk style).</li>
          <li>Локальна ШІ-класифікація фотографій.</li>
        </ul>
      ]]></description>
      <pubDate>Thu, 21 May 2026 00:00:00 +0300</pubDate>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <enclosure 
        url="https://github.com/slavashootit/smart-file-sorter/releases/download/v2.0.0/SmartFileSorter.dmg" 
        sparkle:version="2.0.0" 
        sparkle:shortVersionString="2.0.0" 
        sparkle:edSignature="підпис_отриманий_від_sign_update"
        length="45120400" 
        type="application/octet-stream" />
    </item>

    <!-- ТЕСТОВИЙ КАНАЛ (Beta release) -->
    <item>
      <title>Версія 2.1.0-beta1</title>
      <sparkle:channel>beta</sparkle:channel>
      <description><![CDATA[
        <h2>Тестова збірка v2.1-beta1</h2>
        <ul>
          <li>Експериментальна оптимізація MobileCLIP пошуку.</li>
        </ul>
      ]]></description>
      <pubDate>Fri, 22 May 2026 12:00:00 +0300</pubDate>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <enclosure 
        url="https://github.com/slavashootit/smart-file-sorter/releases/download/v2.1.0-beta1/SmartFileSorter-Beta.dmg" 
        sparkle:version="2.0.9" 
        sparkle:shortVersionString="2.1.0-beta1" 
        sparkle:edSignature="підпис_для_бета_збірки"
        length="45890210" 
        type="application/octet-stream" />
    </item>
  </channel>
</rss>
```

---

## 🤖 Автоматизація підпису в CI/CD (GitHub Actions)

При створенні нового релізу у GitHub Actions запускається скрипт підпису з використанням секретного ключа:

```bash
# Генерація підпису
export SPARKLE_SIGNATURE=$(./bin/sign_update -f /path/to/SmartFileSorter.dmg -s "$SPARKLE_PRIVATE_KEY")

# Далі скрипт автоматично підставляє $SPARKLE_SIGNATURE в шаблон appcast.xml 
# та публікує його в гілку gh-pages.
```
