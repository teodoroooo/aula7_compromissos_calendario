# Aula 7 – Permissões e acesso a recursos do dispositivo

**Programação para Dispositivos Móveis – Prof. Arley**

Exercício: **Consulta aos compromissos do calendário**. O app lista os compromissos do calendário do dispositivo para hoje e os próximos seis dias (sete dias no total).

## Funcionalidades

- Pede permissão de acesso ao calendário (`hasPermissions()` e depois `requestPermissions()`).
- Botão **"Consultar compromissos"**.
- Consulta **todos os calendários** do dispositivo (`retrieveCalendars()`).
- Lista os compromissos em **ordem cronológica**.
- Mostra, para cada compromisso: **título, calendário, data e horário de início e fim, local e descrição**.
- Marca os compromissos de **dia inteiro**.
- Mostra um **indicador de carregamento** durante a consulta e desabilita o botão para evitar consultas duplicadas.
- Avisa quando **não há compromissos**, quando o **acesso é negado** ou quando há **falha na consulta**.

## Permissões no Android

Arquivo `android/app/src/main/AndroidManifest.xml`, dentro de `<manifest>` e antes de `<application>`:

```xml
<uses-permission android:name="android.permission.READ_CALENDAR" />
<uses-permission android:name="android.permission.WRITE_CALENDAR" />
```

## Pacote utilizado

- [`device_calendar`](https://pub.dev/packages/device_calendar)

## Como executar

Execute em um dispositivo ou emulador Android:

```bash
flutter pub get
flutter run
```

## Testes

```bash
flutter test
```

Os testes em `test/widget_test.dart` simulam o lado nativo do `device_calendar`. Eles cobrem a permissão negada, o indicador de carregamento, a lista vazia, a falha na consulta e a listagem em ordem cronológica de vários calendários, com identificação dos compromissos de dia inteiro.

Se a compilação der problema, acrescente ao `android/gradle.properties`:

```
kotlin.compiler.execution.strategy=in-process
kotlin.incremental=false
```
