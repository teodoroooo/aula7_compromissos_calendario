import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aula7_compromissos_calendario/main.dart';

const canal = MethodChannel('plugins.builttoroam.com/device_calendar');

/// Simula o lado nativo do device_calendar.
void simularCalendario({
  bool permitido = true,
  List<Map<String, Object?>> calendarios = const [],
  Map<String, List<Map<String, Object?>>> eventos = const {},
  bool falharEventos = false,
  Completer<bool>? aguardarPermissao,
}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(canal, (chamada) async {
    switch (chamada.method) {
      case 'hasPermissions':
        if (aguardarPermissao != null) return aguardarPermissao.future;
        return permitido;
      case 'requestPermissions':
        return permitido;
      case 'retrieveCalendars':
        return jsonEncode(calendarios);
      case 'retrieveEvents':
        if (falharEventos) {
          throw PlatformException(code: 'erro', message: 'falha');
        }
        final id = (chamada.arguments as Map)['calendarId'];
        return jsonEncode(eventos[id] ?? []);
    }
    return null;
  });
}

Map<String, Object?> evento(
  String titulo,
  DateTime inicio,
  DateTime fim, {
  bool diaInteiro = false,
  String? local,
  String? descricao,
}) {
  return {
    'eventTitle': titulo,
    'eventStartDate': inicio.millisecondsSinceEpoch,
    'eventEndDate': fim.millisecondsSinceEpoch,
    'eventAllDay': diaInteiro,
    'eventLocation': local,
    'eventDescription': descricao,
  };
}

Future<void> consultar(WidgetTester tester) async {
  await tester.tap(find.text('Consultar compromissos'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });

  testWidgets('estado inicial', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TelaCompromissos()));

    expect(
      find.text('Pressione o botão para consultar os compromissos.'),
      findsOneWidget,
    );
  });

  testWidgets('informa quando o acesso é negado', (tester) async {
    simularCalendario(permitido: false);
    await tester.pumpWidget(const MaterialApp(home: TelaCompromissos()));

    await consultar(tester);

    expect(find.textContaining('não foi autorizado'), findsOneWidget);
  });

  testWidgets('exibe indicador de carregamento e bloqueia o botão',
      (tester) async {
    final permissao = Completer<bool>();
    simularCalendario(aguardarPermissao: permissao);
    await tester.pumpWidget(const MaterialApp(home: TelaCompromissos()));

    await tester.tap(find.text('Consultar compromissos'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(find.byType(ElevatedButton))
          .onPressed,
      isNull,
    );

    permissao.complete(true);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('informa quando não há compromissos', (tester) async {
    simularCalendario(calendarios: [
      {'id': '1', 'name': 'Pessoal'},
    ]);
    await tester.pumpWidget(const MaterialApp(home: TelaCompromissos()));

    await consultar(tester);

    expect(find.textContaining('Nenhum compromisso'), findsOneWidget);
  });

  testWidgets('informa falha na consulta', (tester) async {
    simularCalendario(
      calendarios: [
        {'id': '1', 'name': 'Pessoal'},
      ],
      falharEventos: true,
    );
    await tester.pumpWidget(const MaterialApp(home: TelaCompromissos()));

    await consultar(tester);

    expect(
      find.text('Não foi possível consultar os compromissos.'),
      findsOneWidget,
    );
  });

  testWidgets('lista compromissos de todos os calendários em ordem cronológica',
      (tester) async {
    final hoje = DateTime.now();
    final base = DateTime(hoje.year, hoje.month, hoje.day);

    simularCalendario(
      calendarios: [
        {'id': '1', 'name': 'Pessoal'},
        {'id': '2', 'name': 'Trabalho'},
      ],
      eventos: {
        '1': [
          evento(
            'Dentista',
            base.add(const Duration(days: 2, hours: 14)),
            base.add(const Duration(days: 2, hours: 15)),
            local: 'Clínica Sorriso',
            descricao: 'Limpeza',
          ),
        ],
        '2': [
          evento(
            'Reunião',
            base.add(const Duration(hours: 9)),
            base.add(const Duration(hours: 10, minutes: 30)),
          ),
          evento(
            'Feriado',
            base.add(const Duration(days: 1)),
            base.add(const Duration(days: 1)),
            diaInteiro: true,
          ),
        ],
      },
    );
    await tester.pumpWidget(const MaterialApp(home: TelaCompromissos()));

    await consultar(tester);

    expect(find.text('3 compromisso(s) encontrado(s).'), findsOneWidget);

    // Ordem cronológica, mesmo vindo de calendários diferentes.
    final titulos = tester
        .widgetList<Text>(find.byType(Text))
        .map((texto) => texto.data)
        .where((t) => ['Reunião', 'Feriado', 'Dentista'].contains(t))
        .toList();
    expect(titulos, ['Reunião', 'Feriado', 'Dentista']);

    final dataHoje = formatarData(base);
    expect(find.text('Calendário: Trabalho'), findsNWidgets(2));
    expect(find.text('Calendário: Pessoal'), findsOneWidget);
    expect(find.text('Horário: $dataHoje 09:00 – 10:30'), findsOneWidget);
    expect(find.text('Local: Clínica Sorriso'), findsOneWidget);
    expect(find.text('Descrição: Limpeza'), findsOneWidget);
    expect(find.text('Local: Local não informado'), findsNWidgets(2));

    // Compromisso de dia inteiro é identificado.
    expect(find.widgetWithText(Chip, 'Dia inteiro'), findsOneWidget);
    expect(
      find.text(
        'Horário: ${formatarData(base.add(const Duration(days: 1)))} '
        '• Dia inteiro',
      ),
      findsOneWidget,
    );
  });
}
