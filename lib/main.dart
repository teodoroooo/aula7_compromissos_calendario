import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TelaCompromissos(),
    ),
  );
}

/// Compromisso já preparado para exibição, com o nome do calendário de origem.
class Compromisso {
  final String titulo;
  final String calendario;
  final DateTime? inicio;
  final DateTime? fim;
  final bool diaInteiro;
  final String local;
  final String descricao;

  const Compromisso({
    required this.titulo,
    required this.calendario,
    required this.inicio,
    required this.fim,
    required this.diaInteiro,
    required this.local,
    required this.descricao,
  });
}

String formatarData(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');

  return '$dia/$mes/${data.year}';
}

String formatarHora(DateTime data) {
  final hora = data.hour.toString().padLeft(2, '0');
  final minuto = data.minute.toString().padLeft(2, '0');

  return '$hora:$minuto';
}

class TelaCompromissos extends StatefulWidget {
  const TelaCompromissos({super.key});

  @override
  State<TelaCompromissos> createState() => _TelaCompromissosState();
}

class _TelaCompromissosState extends State<TelaCompromissos> {
  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();

  List<Compromisso> _compromissos = [];

  bool _carregando = false;
  String _mensagem = 'Pressione o botão para consultar os compromissos.';

  String _textoOuPadrao(String? texto, String padrao) {
    if (texto == null || texto.trim().isEmpty) {
      return padrao;
    }

    return texto.trim();
  }

  /// Converte a data do evento para o horário local do dispositivo.
  /// Em compromissos de dia inteiro, mantém o dia informado pelo calendário,
  /// evitando que a conversão de fuso mude a data.
  DateTime? _converterData(DateTime? data, bool diaInteiro) {
    if (data == null) return null;

    if (diaInteiro) {
      return DateTime(data.year, data.month, data.day);
    }

    return DateTime.fromMillisecondsSinceEpoch(data.millisecondsSinceEpoch);
  }

  Future<bool> _verificarPermissao() async {
    var permissao = await _plugin.hasPermissions();

    if (permissao.isSuccess && permissao.data == true) {
      return true;
    }

    permissao = await _plugin.requestPermissions();

    return permissao.isSuccess && permissao.data == true;
  }

  Future<void> _consultarCompromissos() async {
    if (_carregando) return;

    setState(() {
      _carregando = true;
      _compromissos = [];
      _mensagem = 'Verificando acesso ao calendário...';
    });

    try {
      final autorizado = await _verificarPermissao();

      if (!mounted) return;

      if (!autorizado) {
        setState(() {
          _mensagem =
              'O acesso ao calendário não foi autorizado. '
              'Caso tenha negado permanentemente, autorize nas '
              'configurações do aplicativo.';
        });

        return;
      }

      setState(() {
        _mensagem = 'Consultando compromissos...';
      });

      final calendarios = await _plugin.retrieveCalendars();

      if (!mounted) return;

      if (!calendarios.isSuccess || calendarios.data == null) {
        setState(() {
          _mensagem = 'Não foi possível consultar os calendários.';
        });

        return;
      }

      // Período: hoje (a partir de 00:00) e os próximos seis dias.
      final agora = DateTime.now();
      final inicioPeriodo = DateTime(agora.year, agora.month, agora.day);
      final fimPeriodo = inicioPeriodo.add(const Duration(days: 7));

      final compromissos = <Compromisso>[];
      var falhas = 0;

      for (final calendario in calendarios.data!) {
        final eventos = await _plugin.retrieveEvents(
          calendario.id,
          RetrieveEventsParams(startDate: inicioPeriodo, endDate: fimPeriodo),
        );

        if (!eventos.isSuccess || eventos.data == null) {
          falhas++;
          continue;
        }

        for (final evento in eventos.data!) {
          final diaInteiro = evento.allDay ?? false;

          compromissos.add(
            Compromisso(
              titulo: _textoOuPadrao(evento.title, 'Compromisso sem título'),
              calendario: _textoOuPadrao(calendario.name, 'Sem nome'),
              inicio: _converterData(evento.start, diaInteiro),
              fim: _converterData(evento.end, diaInteiro),
              diaInteiro: diaInteiro,
              local: _textoOuPadrao(evento.location, 'Local não informado'),
              descricao: _textoOuPadrao(
                evento.description,
                'Sem descrição',
              ),
            ),
          );
        }
      }

      if (!mounted) return;

      // Ordem cronológica; compromissos sem data de início ficam no final.
      compromissos.sort((a, b) {
        if (a.inicio == null && b.inicio == null) return 0;
        if (a.inicio == null) return 1;
        if (b.inicio == null) return -1;

        return a.inicio!.compareTo(b.inicio!);
      });

      setState(() {
        _compromissos = compromissos;

        if (calendarios.data!.isNotEmpty &&
            falhas == calendarios.data!.length) {
          _mensagem = 'Não foi possível consultar os compromissos.';
        } else if (compromissos.isEmpty) {
          _mensagem = 'Nenhum compromisso para hoje e os próximos seis dias.';
        } else {
          _mensagem = '${compromissos.length} compromisso(s) encontrado(s).';
        }

        if (falhas > 0 && falhas < calendarios.data!.length) {
          _mensagem += ' $falhas calendário(s) não puderam ser consultados.';
        }
      });
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        _mensagem = 'Não foi possível consultar os compromissos.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  String _descreverHorario(Compromisso compromisso) {
    final inicio = compromisso.inicio;
    final fim = compromisso.fim;

    if (inicio == null) return 'Data não informada';

    if (compromisso.diaInteiro) {
      // No calendário, o fim de um evento de dia inteiro é o dia seguinte
      // ao último dia do evento.
      final ultimoDia = fim?.subtract(const Duration(days: 1));

      if (ultimoDia == null || !ultimoDia.isAfter(inicio)) {
        return '${formatarData(inicio)} • Dia inteiro';
      }

      return '${formatarData(inicio)} a ${formatarData(ultimoDia)} • '
          'Dia inteiro';
    }

    final textoInicio = '${formatarData(inicio)} ${formatarHora(inicio)}';

    if (fim == null) return 'Início: $textoInicio';

    final mesmoDia = inicio.year == fim.year &&
        inicio.month == fim.month &&
        inicio.day == fim.day;

    final textoFim =
        mesmoDia ? formatarHora(fim) : '${formatarData(fim)} ${formatarHora(fim)}';

    return '$textoInicio – $textoFim';
  }

  Widget _cartaoCompromisso(Compromisso compromisso) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    compromisso.titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (compromisso.diaInteiro)
                  const Chip(label: Text('Dia inteiro')),
              ],
            ),
            const SizedBox(height: 4),
            Text('Calendário: ${compromisso.calendario}'),
            Text('Horário: ${_descreverHorario(compromisso)}'),
            Text('Local: ${compromisso.local}'),
            Text('Descrição: ${compromisso.descricao}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compromissos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: _carregando ? null : _consultarCompromissos,
                  child: const Text('Consultar compromissos'),
                ),
                const SizedBox(height: 12),
                Text(_mensagem, textAlign: TextAlign.center),
              ],
            ),
          ),
          if (_carregando) const CircularProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _compromissos.length,
              itemBuilder: (context, indice) {
                return _cartaoCompromisso(_compromissos[indice]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
