// ============================================================
// PANTALLA PRINCIPAL: CalendarioScreen
// ============================================================
// Este archivo contiene la pantalla principal de la app con dos
// secciones navegables desde la barra inferior:
//
//   1. PANTALLA CALENDARIO (_buildPaginaCalendario):
//      - Buscadores de Alumnos y Profesores (lado a lado)
//      - Carrusel horizontal de días
//      - Lista de cards con las actividades del día
//      - Modal Bottom Sheet con los detalles (_mostrarDetalles)
//
//   2. PANTALLA INFORMACIÓN (_buildPaginaInformacion):
//      - Card expandible del REGLAMENTO (de App_Info)
//      - Divider entre secciones
//      - Sección FAQ - Preguntas Frecuentes (de Info_App)
//
// MÉTODOS AUXILIARES (al final del archivo):
//      - _agruparPorDiaYHora: agrupa actividades por horario
//      - _extraerReglamento: extrae el texto del reglamento
//      - _buildTextoConLinks: renderiza texto con URLs clickeables
//      - _abrirUrl: abre enlaces externos (url_launcher)
//      - _formatearHora / _formatearFechaLarga: formato de fechas
//      - _estaEnElPasado / _determinarColorBorde: estado visual
//        de las cards (borde verde = futuro, rojo = pasado)
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/actividad_services.dart';

class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  final ActividadService _actividadService = ActividadService();
  String? _idAlumnoSeleccionado;
  String? _profesorSeleccionado;
  String? _diaSeleccionado;
  late Future<Map<String, dynamic>> _fetchFuture;
  int _indiceActual = 0;

  // Configuración de fechas para el curso (21 al 31 de agosto de 2026)
  final Map<String, DateTime> _mapeoFechas = {
    for (int i = 21; i <= 31; i++) 'Día $i': DateTime(2026, 8, i),
  };

  // Variable para simular la fecha y hora actual (para pruebas)
  // Si es null, utiliza la fecha real del sistema.
  final DateTime? _fechaManualDePrueba = null;

  DateTime get _ahora => _fechaManualDePrueba ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchFuture = _actividadService.obtenerActividades();
  }

  // ==========================================================
  // ESTRUCTURA PRINCIPAL: Scaffold con AppBar, body y bottom bar
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- BARRA SUPERIOR (AppBar) ---
      // Muestra el título según la pestaña activa
      appBar: AppBar(
        title: Text(
          _indiceActual == 0 ? 'CALENDARIO' : 'INFORMACIÓN',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.tertiary,
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      // --- CUERPO PRINCIPAL ---
      // FutureBuilder: carga los datos del backend (Google Sheets)
      // y muestra indicador de carga / error / contenido
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sincronizando cronograma...',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data ?? {};

          if (snapshot.hasError || data.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade700),
                  const SizedBox(height: 16),
                  const Text('No se pudo cargar la información'),
                  TextButton(
                    onPressed: () => setState(() {
                      _fetchFuture = _actividadService.obtenerActividades();
                    }),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          // IndexedStack: mantiene vivas ambas pantallas y
          // alterna entre ellas según la pestaña seleccionada
          return IndexedStack(
            index: _indiceActual,
            children: [
              // PANTALLA 0: CALENDARIO
              _buildPaginaCalendario(data),
              // PANTALLA 1: INFORMACIÓN (Reglamento + FAQ)
              _buildPaginaInformacion(
                appInfoList: data['App_Info'] as List<dynamic>? ?? [],
                faqList: data['Info_App'] as List<dynamic>? ?? [],
              ),
            ],
          );
        },
      ),
      // --- BARRA DE NAVEGACIÓN INFERIOR (BottomNavigationBar) ---
      // Pestañas: Calendario | Información
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _indiceActual,
          onTap: (index) => setState(() => _indiceActual = index),
          selectedItemColor: Theme.of(context).colorScheme.tertiary,
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Calendario',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.info_outline),
              activeIcon: Icon(Icons.info),
              label: 'Información',
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // PANTALLA CALENDARIO
  // ==========================================================
  // Contiene: buscadores, carrusel de días y lista de actividades
  Widget _buildPaginaCalendario(Map<String, dynamic> data) {
    final masterAlumnos = data['Alumnos_App'] as List<dynamic>? ?? [];
    final calendarioCurso = data['Calendario_App'] as List<dynamic>? ?? [];

    // Crear mapa de búsqueda para nombres de alumnos
    final Map<String, String> mapeoAlumnos = {
      'ALU-TODOS': 'Todos los participantes',
      'ALU-Todos': 'Todos los participantes',
      'ALU-todos': 'Todos los participantes',
      for (var a in masterAlumnos)
        a['ID'].toString().trim():
            a['Nombre']?.toString().trim() ?? a['ID'].toString().trim(),
    };

    if (calendarioCurso.isEmpty && masterAlumnos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade700),
            const SizedBox(height: 16),
            const Text('No se pudo cargar el cronograma'),
            TextButton(
              onPressed: () => setState(() {
                _fetchFuture = _actividadService.obtenerActividades();
              }),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    // Filtrar alumnos para el dropdown (excluyendo ALU-TODOS)
    final listaDropdown = masterAlumnos.where((a) {
      final id = a['ID']?.toString().trim() ?? '';
      return id.isNotEmpty && id.toUpperCase() != 'ALU-TODOS';
    }).toList();

    // Ordenar alfabéticamente por nombre completo
    listaDropdown.sort((a, b) {
      final idA = a['ID'].toString().trim();
      final idB = b['ID'].toString().trim();
      final nombreA = (mapeoAlumnos[idA] ?? idA).toLowerCase();
      final nombreB = (mapeoAlumnos[idB] ?? idB).toLowerCase();
      return nombreA.compareTo(nombreB);
    });

    // Generar los días fijos del 21 al 31 de agosto
    final setDias = List.generate(11, (index) => '${21 + index}');

    // Seleccionar por defecto el día actual si está dentro del rango del curso
    if (_diaSeleccionado == null && setDias.isNotEmpty) {
      final hoy = _ahora;
      final diaHoyString = hoy.day.toString();
      if (setDias.contains(diaHoyString)) {
        _diaSeleccionado = diaHoyString;
      } else {
        _diaSeleccionado = setDias.first;
      }
    }

    // Generar lista de profesores únicos
    final setProfesores = <String>{};
    for (var clase in calendarioCurso) {
      final prof = clase['Profesor']?.toString().trim() ?? '';
      if (prof.isNotEmpty && prof != 'Todos lo profesores') {
        setProfesores.add(prof);
      }
    }
    final listaProfesores = setProfesores.toList()..sort();

    // Lógica de filtrado de actividades
    List<dynamic> filtrado = calendarioCurso;

    if (_idAlumnoSeleccionado != null) {
      filtrado = filtrado.where((clase) {
        final id = clase['Alumno']?.toString().trim() ?? '';
        return id == _idAlumnoSeleccionado || id.toUpperCase() == 'ALU-TODOS';
      }).toList();
    }

    if (_profesorSeleccionado != null) {
      filtrado = filtrado.where((clase) {
        final prof = clase['Profesor']?.toString().trim() ?? '';
        return prof == _profesorSeleccionado || prof == 'Todos lo profesores';
      }).toList();
    }

    // Luego filtrar por Día seleccionado
    final calendarioFiltrado = filtrado.where((clase) {
      final diaRaw = clase['Dia']?.toString() ?? '';
      return diaRaw == _diaSeleccionado;
    }).toList();

    final bloquesHorarios = _agruparPorDiaYHora(calendarioFiltrado);

    return Column(
      children: [
        // ----------------------------------------------------
        // BUSCADORES DE ALUMNOS Y PROFESORES (lado a lado)
        // ----------------------------------------------------
        // - Izquierda: DropdownMenu de Alumnos (hint: "Alumnos")
        // - Derecha: DropdownMenu de Profesores (hint: "Profesores")
        // Al seleccionar uno, el otro se resetea automáticamente
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: DropdownMenu<String>(
                  initialSelection: _idAlumnoSeleccionado,
                  hintText: "Alumnos",
                  enableSearch: true,
                  enableFilter: true,
                  requestFocusOnTap: true,
                  leadingIcon: const Icon(Icons.search, size: 20),
                  trailingIcon: Icon(
                    Icons.keyboard_arrow_down,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  selectedTrailingIcon: Icon(
                    Icons.keyboard_arrow_up,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textStyle: const TextStyle(fontSize: 16),
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                  ),
                  menuStyle: MenuStyle(
                    backgroundColor: WidgetStateProperty.all(
                      Theme.of(context).cardColor,
                    ),
                    elevation: WidgetStateProperty.all(8),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                  ),
                  dropdownMenuEntries: [
                    const DropdownMenuEntry<String>(
                      value: 'TODOS_FILTRO',
                      label: "Alumnos",
                      leadingIcon: Icon(Icons.groups_outlined, size: 18),
                    ),
                    ...listaDropdown.map((a) {
                      final id = a['ID'].toString().trim();
                      final nombreCompleto = mapeoAlumnos[id] ?? id;
                      return DropdownMenuEntry<String>(
                        value: id,
                        label: nombreCompleto,
                        leadingIcon: const Icon(Icons.person_outline, size: 18),
                      );
                    }),
                  ],
                  onSelected: (String? nuevoId) {
                    setState(() {
                      _idAlumnoSeleccionado = (nuevoId == 'TODOS_FILTRO')
                          ? null
                          : nuevoId;
                      // Si se selecciona un alumno específico, resetear profesor
                      if (_idAlumnoSeleccionado != null) {
                        _profesorSeleccionado = null;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownMenu<String>(
                  initialSelection: _profesorSeleccionado,
                  hintText: "Profesores",
                  enableSearch: true,
                  enableFilter: true,
                  requestFocusOnTap: true,
                  leadingIcon: const Icon(Icons.school_outlined, size: 20),
                  trailingIcon: Icon(
                    Icons.keyboard_arrow_down,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  selectedTrailingIcon: Icon(
                    Icons.keyboard_arrow_up,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textStyle: const TextStyle(fontSize: 16),
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                  ),
                  menuStyle: MenuStyle(
                    backgroundColor: WidgetStateProperty.all(
                      Theme.of(context).cardColor,
                    ),
                    elevation: WidgetStateProperty.all(8),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                  ),
                  dropdownMenuEntries: [
                    const DropdownMenuEntry<String>(
                      value: 'TODOS_FILTRO',
                      label: "Profesores",
                      leadingIcon: Icon(Icons.groups_outlined, size: 18),
                    ),
                    ...listaProfesores.map((prof) {
                      return DropdownMenuEntry<String>(
                        value: prof,
                        label: prof,
                        leadingIcon: const Icon(
                          Icons.school_outlined,
                          size: 18,
                        ),
                      );
                    }),
                  ],
                  onSelected: (String? nuevoProfesor) {
                    setState(() {
                      _profesorSeleccionado = (nuevoProfesor == 'TODOS_FILTRO')
                          ? null
                          : nuevoProfesor;
                      // Si se selecciona un profesor específico, resetear alumno
                      if (_profesorSeleccionado != null) {
                        _idAlumnoSeleccionado = null;
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ),

        // ----------------------------------------------------
        // CARRUSEL HORIZONTAL DE DÍAS (21 al 31)
        // ----------------------------------------------------
        // Muestra solo el número del día; el día seleccionado se
        // resalta con borde dorado. Por defecto se selecciona hoy.
        if (setDias.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Row(
                children: setDias.map((dia) {
                  final esSeleccionado = _diaSeleccionado == dia;
                  return GestureDetector(
                    onTap: () => setState(() => _diaSeleccionado = dia),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: EdgeInsets.only(
                        right: dia == setDias.last ? 0 : 8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: esSeleccionado
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: esSeleccionado
                              ? Theme.of(context).colorScheme.tertiary
                              : Colors.white.withValues(alpha: 0.05),
                          width: esSeleccionado ? 1.0 : 1,
                        ),
                      ),
                      child: Text(
                        dia,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: esSeleccionado
                              ? Theme.of(context).colorScheme.tertiary
                              : Colors.white38,
                          fontWeight: esSeleccionado
                              ? FontWeight.w900
                              : FontWeight.w500,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        // ----------------------------------------------------
        // LISTA DE ACTIVIDADES (CARDS)
        // ----------------------------------------------------
        // Cada card muestra: hora inicio/fin, tipos de actividad
        // y nombres de alumnos. Borde izquierdo:
        //   verde = actividad futura | rojo = actividad pasada
        // Al presionar una card se abre el Modal Bottom Sheet
        // ----------------------------------------------------
        // LISTA DE ACTIVIDADES CON SWIPE REFRESH
        // ----------------------------------------------------
        // Deslizar hacia abajo recarga los datos del backend
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _fetchFuture = _actividadService.obtenerActividades();
              });
            },
            color: Theme.of(context).colorScheme.tertiary,
            backgroundColor: Theme.of(context).cardColor,
            child: bloquesHorarios.isEmpty
                ? Center(
                    child: Text(
                      'No hay actividades programadas',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: bloquesHorarios.length,
                    itemBuilder: (context, index) {
                      final bloque = bloquesHorarios[index];

                      bool mostrarEncabezadoDia = false;
                      if (index == 0) {
                        mostrarEncabezadoDia = true;
                      } else {
                        final bloqueAnterior = bloquesHorarios[index - 1];
                        if (bloque['Dia'] != bloqueAnterior['Dia']) {
                          mostrarEncabezadoDia = true;
                        }
                      }

                      return TweenAnimationBuilder<double>(
                        duration: Duration(
                          milliseconds: 400 + (index % 10 * 50),
                        ),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (mostrarEncabezadoDia)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 20,
                                  top: 24,
                                  bottom: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatearFechaLarga(
                                        bloque['Dia'],
                                      ).toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            letterSpacing: 1.5,
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                            // --- CARD DE ACTIVIDAD ---
                            // Franja izquierda de color según estado
                            // (verde/rojo). onTap abre el Bottom Sheet
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border(
                                  left: BorderSide(
                                    color: _determinarColorBorde(bloque),
                                    width: 5,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Opacity(
                                opacity: _estaEnElPasado(bloque) ? 0.6 : 1.0,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _mostrarDetalles(
                                    context,
                                    bloque,
                                    mapeoAlumnos,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Row(
                                      children: [
                                        // Bloque Horario
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              bloque['Inicio'] ?? '--:--',
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .tertiary
                                                    .withValues(alpha: 0.9),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                              ),
                                            ),
                                            Text(
                                              bloque['Fin'] ?? '--:--',
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 24),
                                        // Divisor vertical sutil
                                        Container(
                                          width: 1,
                                          height: 40,
                                          color: Colors.white10,
                                        ),
                                        const SizedBox(width: 24),
                                        // Resumen Actividad
                                        Expanded(
                                          child: Builder(
                                            builder: (context) {
                                              final listaClases =
                                                  bloque['listaClases']
                                                      as List<dynamic>;

                                              // Extraer todas las actividades únicas del bloque
                                              final actividadesUnicas =
                                                  listaClases
                                                      .map(
                                                        (c) =>
                                                            c['Tipo Actividad']
                                                                ?.toString()
                                                                .trim() ??
                                                            '',
                                                      )
                                                      .where(
                                                        (a) => a.isNotEmpty,
                                                      )
                                                      .toSet()
                                                      .toList();

                                              final actividadPrincipal =
                                                  _formatearListaActividades(
                                                    actividadesUnicas,
                                                  );

                                              // Extraer y formatear la lista de alumnos
                                              final alumnos = listaClases
                                                  .map((c) {
                                                    final id =
                                                        c['Alumno']
                                                            ?.toString()
                                                            .trim() ??
                                                        '';
                                                    return mapeoAlumnos[id] ??
                                                        id;
                                                  })
                                                  .where((n) => n.isNotEmpty)
                                                  .toList();

                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    actividadPrincipal
                                                        .toUpperCase(),
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade400,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 1.1,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    alumnos.isEmpty
                                                        ? 'General'
                                                        : alumnos.join(', '),
                                                    style: const TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      letterSpacing: 0.2,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          size: 20,
                                          color: Colors.grey.shade700,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // PANTALLA INFORMACIÓN
  // ==========================================================
  // Contiene:
  //   1. Card expandible del REGLAMENTO (datos de App_Info,
  //      o extraído de Info_App si viene como pregunta)
  //   2. Divider entre secciones
  //   3. Título "PREGUNTAS FRECUENTES" con icono
  //   4. Cards expandibles del FAQ (datos de Info_App)
  Widget _buildPaginaInformacion({
    required List<dynamic> appInfoList,
    required List<dynamic> faqList,
  }) {
    // Extraemos el reglamento si existe en appInfoList
    final reglamentoItem = appInfoList.isNotEmpty ? appInfoList.first : null;
    String reglamentoTexto = _extraerReglamento(reglamentoItem);

    // Filtramos la lista de FAQ para separar el Reglamento si viene allí
    final filteredFaqList = <dynamic>[];
    for (var item in faqList) {
      final pregunta = item['Pregunta']?.toString().trim().toLowerCase() ?? '';
      if (pregunta == 'reglamento') {
        if (reglamentoTexto.isEmpty) {
          reglamentoTexto = item['Respuesta']?.toString().trim() ?? '';
        }
      } else {
        filteredFaqList.add(item);
      }
    }

    final tieneReglamento = reglamentoTexto.isNotEmpty;
    final tieneFaq = filteredFaqList.isNotEmpty;

    if (!tieneReglamento && !tieneFaq) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Información del Curso',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Próximamente encontrarás aquí información relevante sobre el curso.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ------------------------------------------------
          // CARD DEL REGLAMENTO (expandible)
          // ------------------------------------------------
          // Icono de mazo de juez en círculo dorado. Al
          // expandirse muestra el texto completo del reglamento
          if (tieneReglamento) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
              child: Card(
                color: Theme.of(context).cardColor,
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.tertiary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.gavel,
                            size: 18,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'REGLAMENTO',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    iconColor: Theme.of(context).colorScheme.tertiary,
                    collapsedIconColor: Colors.white38,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        // Renderiza el reglamento con formato Markdown
                        // (negritas, listas, títulos, etc.) y abre
                        // los enlaces en apps externas al tocarlos
                        child: MarkdownBody(
                          data: reglamentoTexto,
                          onTapLink: (text, href, title) {
                            if (href != null) _abrirUrl(href);
                          },
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade400,
                              height: 1.5,
                            ),
                            strong: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            listBullet: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade400,
                            ),
                            h1: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            h2: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            h3: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            a: TextStyle(
                              color: Theme.of(context).colorScheme.tertiary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // ------------------------------------------------
          // DIVIDER entre Reglamento y FAQ + TÍTULO del FAQ
          // ------------------------------------------------
          if (tieneReglamento && tieneFaq) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
              child: Divider(
                color: Colors.white.withValues(alpha: 0.1),
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'PREGUNTAS FRECUENTES',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.tertiary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (tieneFaq) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'PREGUNTAS FRECUENTES',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.tertiary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ------------------------------------------------
          // LISTA DE PREGUNTAS FRECUENTES (FAQ)
          // ------------------------------------------------
          // Cards expandibles con icono de interrogación en
          // círculo dorado. Las respuestas soportan enlaces
          // clickeables (ej. Google Maps)
          if (tieneFaq) ...[
            ...filteredFaqList.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final pregunta = item['Pregunta']?.toString().trim() ?? '';
              final respuesta = item['Respuesta']?.toString().trim() ?? '';

              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 400 + (index % 10 * 50)),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Card(
                    color: Theme.of(context).cardColor,
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.tertiary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.help_outline,
                                size: 18,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                pregunta,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        iconColor: Theme.of(context).colorScheme.tertiary,
                        collapsedIconColor: Colors.white38,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: _buildTextoConLinks(respuesta),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ==========================================================
  // MODAL BOTTOM SHEET: Detalles de la actividad
  // ==========================================================
  // Se abre al presionar una card del calendario.
  // Muestra: fecha, horario, y por cada actividad del bloque:
  //   - Icono (persona para clases, nota musical para general)
  //   - Nombre del alumno o tipo de actividad
  //   - PROF. / PIANISTA / ESPACIO (columna derecha)
  void _mostrarDetalles(
    BuildContext context,
    Map<String, dynamic> bloque,
    Map<String, String> mapeoAlumnos,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final listaClases = bloque['listaClases'] as List<dynamic>;
        final clasesValidas = listaClases.where((c) {
          final act = c['Tipo Actividad']?.toString().trim() ?? '';
          final alu = c['Alumno']?.toString().trim() ?? '';
          return act.isNotEmpty || alu.isNotEmpty;
        }).toList();

        return Container(
          // Limitar altura máxima al 80% de la pantalla para
          // evitar overflow cuando hay muchas actividades
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(bottomSheetContext).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          // SingleChildScrollView permite desplazar el contenido
          // cuando supera la altura máxima disponible
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatearFechaLarga(bloque['Dia']),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.tertiary,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      bloque['Inicio'] ?? '--:--',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                ...clasesValidas.map((clase) {
                  final idAlumno = clase['Alumno']?.toString().trim() ?? '';
                  final esClase =
                      idAlumno.isNotEmpty &&
                      idAlumno.toUpperCase() != 'ALU-TODOS';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.tertiary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _obtenerIconoActividad(clase, esClase),
                            color: Theme.of(context).colorScheme.tertiary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                esClase
                                    ? (mapeoAlumnos[idAlumno] ?? idAlumno)
                                    : (clase['Tipo Actividad'] ?? 'Actividad'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              if (esClase &&
                                  clase['Tipo Actividad'] != null) ...[
                                Text(
                                  clase['Tipo Actividad'],
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                ),
                              ] else if (!esClase &&
                                  idAlumno.toUpperCase() == 'ALU-TODOS') ...[
                                Text(
                                  'Todos los participantes',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                              // Hora de inicio y fin de cada actividad
                              Text(
                                '${_formatearHora(clase['Inicio'])} — ${_formatearHora(clase['Fin'])}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (clase['Profesor']
                                    ?.toString()
                                    .trim()
                                    .isNotEmpty ==
                                true) ...[
                              const Text(
                                'PROF.',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                clase['Profesor'].toString().trim(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            if (clase['Pianista']
                                    ?.toString()
                                    .trim()
                                    .isNotEmpty ==
                                true) ...[
                              if (clase['Profesor']
                                      ?.toString()
                                      .trim()
                                      .isNotEmpty ==
                                  true)
                                const SizedBox(height: 8),
                              const Text(
                                'PIANISTA',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                clase['Pianista'].toString().trim(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            if (clase['Espacio']
                                    ?.toString()
                                    .trim()
                                    .isNotEmpty ==
                                true) ...[
                              if (clase['Profesor']
                                          ?.toString()
                                          .trim()
                                          .isNotEmpty ==
                                      true ||
                                  clase['Pianista']
                                          ?.toString()
                                          .trim()
                                          .isNotEmpty ==
                                      true)
                                const SizedBox(height: 8),
                              const Text(
                                'ESPACIO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                clase['Espacio'].toString().trim(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================
  // MÉTODOS AUXILIARES
  // ==========================================================

  // --- AGRUPAMIENTO CRONOLÓGICO ---
  // Agrupa las actividades por día y hora de inicio en bloques.
  // Cada bloque contiene la lista de clases que ocurren a esa hora.
  List<Map<String, dynamic>> _agruparPorDiaYHora(List<dynamic> clasesCrudas) {
    final Map<String, List<dynamic>> bloques = {};

    for (var clase in clasesCrudas) {
      final diaRaw = clase['Dia']?.toString() ?? '';
      final dia = 'Día $diaRaw';

      final horaInicio = _formatearHora(clase['Inicio']);
      final llaveUnica = '$dia|$horaInicio';

      if (!bloques.containsKey(llaveUnica)) {
        bloques[llaveUnica] = [];
      }
      bloques[llaveUnica]!.add(clase);
    }

    final listaAgrupada = bloques.entries
        .map((entrada) {
          final partes = entrada.key.split('|');
          final clasesDelBloque = entrada.value;
          final horaFin = _formatearHora(clasesDelBloque.first['Fin']);

          return {
            'Dia': partes[0],
            'Inicio': partes[1],
            'Fin': horaFin,
            'listaClases': clasesDelBloque,
          };
        })
        .where((bloque) {
          // Filtramos bloques que no tengan ninguna actividad real
          // y excluimos las actividades "Espacio disponible"
          final lista = bloque['listaClases'] as List<dynamic>;
          return lista.any((c) {
            final alu = c['Alumno']?.toString().trim() ?? '';
            final act = c['Tipo Actividad']?.toString().trim() ?? '';
            final esEspacioDisponible =
                act.toLowerCase() == 'espacio disponible';
            return (alu.isNotEmpty || act.isNotEmpty) && !esEspacioDisponible;
          });
        })
        .toList();

    // Ordenamiento estricto por Día y luego por Hora de Inicio
    listaAgrupada.sort((a, b) {
      String diaA = a['Dia'].toString();
      String diaB = b['Dia'].toString();
      int compDia = diaA.compareTo(diaB);

      if (compDia != 0) return compDia;

      return (a['Inicio'] as String).compareTo(b['Inicio'] as String);
    });

    return listaAgrupada;
  }

  // --- EXTRACCIÓN DEL REGLAMENTO ---
  // Busca el texto del reglamento en App_Info probando varios
  // nombres de campo posibles (Reglamento, Contenido, Texto...)
  String _extraerReglamento(dynamic item) {
    if (item == null) return '';
    if (item is! Map<String, dynamic>) return item.toString().trim();

    // Buscar campos comunes para el reglamento
    final posiblesCampos = [
      'Reglamento',
      'reglamento',
      'Contenido',
      'contenido',
      'Texto',
      'texto',
      'Descripcion',
      'descripcion',
      'Descripción',
      'descripción',
      'Info',
      'info',
    ];

    for (final campo in posiblesCampos) {
      final valor = item[campo];
      if (valor != null && valor.toString().trim().isNotEmpty) {
        return valor.toString().trim();
      }
    }

    // Si no hay campos conocidos, usar el primer campo de texto no vacío
    for (final entry in item.entries) {
      final valor = entry.value?.toString().trim() ?? '';
      if (valor.isNotEmpty) {
        return valor;
      }
    }

    return '';
  }

  // --- TEXTO CON ENLACES CLICKEABLES ---
  // Detecta URLs en el texto y las convierte en botones
  // dorados "Abrir enlace" que abren la app externa
  Widget _buildTextoConLinks(String texto) {
    final urlRegex = RegExp(
      r"https?:\/\/(?:[\w\-\.]+)(?:\/[\w\-\.~:\/?#\[\]@!$&\'()*+,;=%]*)?",
      caseSensitive: false,
    );

    final matches = urlRegex.allMatches(texto).toList();
    if (matches.isEmpty) {
      return Text(
        texto,
        style: TextStyle(
          fontSize: 15,
          color: Colors.grey.shade400,
          height: 1.5,
        ),
      );
    }

    final children = <Widget>[];
    int currentIndex = 0;

    for (final match in matches) {
      // Texto antes del enlace
      if (match.start > currentIndex) {
        final textoPrevio = texto.substring(currentIndex, match.start).trim();
        if (textoPrevio.isNotEmpty) {
          children.add(
            Text(
              textoPrevio,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade400,
                height: 1.5,
              ),
            ),
          );
        }
      }

      // Botón de enlace destacado
      final url = match.group(0)!;
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: InkWell(
            onTap: () => _abrirUrl(url),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.tertiary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.tertiary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Abrir enlace',
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      currentIndex = match.end;
    }

    // Texto después del último enlace
    if (currentIndex < texto.length) {
      final textoFinal = texto.substring(currentIndex).trim();
      if (textoFinal.isNotEmpty) {
        children.add(
          Text(
            textoFinal,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade400,
              height: 1.5,
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  // --- ABRIR URL EXTERNA ---
  // Abre el enlace en el navegador o app correspondiente
  Future<void> _abrirUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // --- FORMATEO DE LISTA DE ACTIVIDADES ---
  // Une tipos de actividad: "A", "A y B", "A, B y C"
  String _formatearListaActividades(List<String> actividades) {
    if (actividades.isEmpty) return 'Actividad';
    if (actividades.length == 1) return actividades.first;

    // Para dos o más actividades: "A y B" o "A, B y C"
    final todasMenosUltima = actividades.sublist(0, actividades.length - 1);
    final ultima = actividades.last;
    return '${todasMenosUltima.join(', ')} y $ultima';
  }

  // --- FORMATEO DE HORA ---
  // Convierte el valor del backend (ISO 1899-12-30T... o HH:MM)
  // a formato legible "HH:MM"
  String _formatearHora(dynamic valor) {
    if (valor == null) return '--:--';

    final texto = valor.toString().trim();
    if (texto.isEmpty) return '--:--';

    // Si ya viene como HH:MM o H:MM
    if (texto.contains(':') && !texto.startsWith('1899')) {
      final partes = texto.split(':');
      if (partes.length >= 2) {
        final hora = int.tryParse(partes[0]) ?? 0;
        final minuto = int.tryParse(partes[1]) ?? 0;
        return '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';
      }
    }

    // Si viene como fecha ISO de Google Sheets (1899-12-30THH:MM:SS.000Z)
    try {
      final fecha = DateTime.parse(texto);
      final horaLocal = fecha.toLocal();
      return '${horaLocal.hour.toString().padLeft(2, '0')}:${horaLocal.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '--:--';
    }
  }

  // --- FORMATEO DE FECHA LARGA ---
  // Convierte "Día 21" en "Viernes 21 de agosto"
  String _formatearFechaLarga(String diaKey) {
    final fecha = _mapeoFechas[diaKey];
    if (fecha == null) return diaKey;

    final diasSemana = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];

    final diaSemana = diasSemana[fecha.weekday - 1];
    final mes = meses[fecha.month - 1];

    return '$diaSemana ${fecha.day} de $mes';
  }

  // --- DETECTAR ACTIVIDAD PASADA ---
  // Compara la hora de fin de la actividad con la hora actual
  bool _estaEnElPasado(Map<String, dynamic> bloque) {
    final DateTime? fechaBase = _mapeoFechas[bloque['Dia']];
    if (fechaBase == null) return false;

    try {
      final horaFinStr = (bloque['Fin'] as String).trim();
      final partes = horaFinStr.split(':');
      final hora = int.parse(partes[0]);
      final minuto = int.parse(partes[1]);

      final fechaFin = DateTime(
        fechaBase.year,
        fechaBase.month,
        fechaBase.day,
        hora,
        minuto,
      );
      return _ahora.isAfter(fechaFin);
    } catch (e) {
      return false;
    }
  }

  // --- ICONO SEGÚN TIPO DE ACTIVIDAD ---
  // Asigna un icono representativo a cada tipo de actividad general
  IconData _obtenerIconoActividad(Map<String, dynamic> clase, bool esClase) {
    if (esClase) return Icons.person_outline;

    final tipo = (clase['Tipo Actividad']?.toString() ?? '').toLowerCase();

    if (tipo.contains('almuerzo') || tipo.contains('comida')) {
      return Icons.restaurant;
    }
    if (tipo.contains('bienvenida') ||
        tipo.contains('reunión') ||
        tipo.contains('reunion')) {
      return Icons.groups;
    }
    if (tipo.contains('ensayo') ||
        tipo.contains('ensamble') ||
        tipo.contains('ensemble')) {
      return Icons.piano;
    }
    if (tipo.contains('concierto') || tipo.contains('presentación')) {
      return Icons.mic_external_on;
    }
    if (tipo.contains('clase magistral') || tipo.contains('masterclass')) {
      return Icons.school;
    }
    if (tipo.contains('descanso') || tipo.contains('break')) {
      return Icons.free_breakfast;
    }

    // Icono por defecto para actividades generales
    return Icons.event_note;
  }

  // --- COLOR DE LA FRANJA IZQUIERDA DE LA CARD ---
  // Rojo = actividad pasada | Verde = actividad futura
  Color _determinarColorBorde(Map<String, dynamic> bloque) {
    if (_estaEnElPasado(bloque)) {
      return Colors.redAccent;
    }
    return Colors.greenAccent;
  }
}
