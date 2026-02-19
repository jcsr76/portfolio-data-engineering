VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Informe_Estatus_Planta"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

' Lógica de Seleccion del control de Opciones para Fecha Ingreso Colaborador

Private Sub ActualizarControlesFechaIngreso()

    Select Case Me.grpFiltroFechaIngreso
        Case 1   ' Fecha específica
            ' Activar único
            Me.txtFechaIngresoUnica.Visible = True
            Me.txtFechaIngresoUnica.Enabled = True

            ' Desactivar y limpiar rango
            Me.txtFechaIngresoDesde.Value = Null
            Me.txtFechaIngresoDesde.Visible = False
            Me.txtFechaIngresoDesde.Enabled = False

            Me.txtFechaIngresoHasta.Value = Null
            Me.txtFechaIngresoHasta.Visible = False
            Me.txtFechaIngresoHasta.Enabled = False

            ' Desactivar y limpiar periodo
            Me.cboPeriodoFechaIngreso.Value = Null
            Me.cboPeriodoFechaIngreso.Visible = False
            Me.cboPeriodoFechaIngreso.Enabled = False

        Case 2   ' Entre dos fechas
            ' Desactivar y limpiar único
            Me.txtFechaIngresoUnica.Value = Null
            Me.txtFechaIngresoUnica.Visible = False
            Me.txtFechaIngresoUnica.Enabled = False

            ' Activar rango
            Me.txtFechaIngresoDesde.Visible = True
            Me.txtFechaIngresoDesde.Enabled = True

            Me.txtFechaIngresoHasta.Visible = True
            Me.txtFechaIngresoHasta.Enabled = True

            ' Desactivar y limpiar periodo
            Me.cboPeriodoFechaIngreso.Value = Null
            Me.cboPeriodoFechaIngreso.Visible = False
            Me.cboPeriodoFechaIngreso.Enabled = False

        Case 3   ' Periodo rápido
            ' Desactivar y limpiar único
            Me.txtFechaIngresoUnica.Value = Null
            Me.txtFechaIngresoUnica.Visible = False
            Me.txtFechaIngresoUnica.Enabled = False

            ' Desactivar y limpiar rango
            Me.txtFechaIngresoDesde.Value = Null
            Me.txtFechaIngresoDesde.Visible = False
            Me.txtFechaIngresoDesde.Enabled = False

            Me.txtFechaIngresoHasta.Value = Null
            Me.txtFechaIngresoHasta.Visible = False
            Me.txtFechaIngresoHasta.Enabled = False

            ' Activar periodo
            Me.cboPeriodoFechaIngreso.Visible = True
            Me.cboPeriodoFechaIngreso.Enabled = True
    End Select

End Sub

' Lógica de Seleccion del control de Opciones para Fecha Retiro Colaborador

Private Sub ActualizarControlesFechaRetiro()

    Select Case Me.grpFiltroFechaRetiro
        Case 1   ' Fecha específica
            Me.txtFechaRetiroUnica.Visible = True
            Me.txtFechaRetiroUnica.Enabled = True

            Me.txtFechaRetiroDesde.Value = Null
            Me.txtFechaRetiroDesde.Visible = False
            Me.txtFechaRetiroDesde.Enabled = False

            Me.txtFechaRetiroHasta.Value = Null
            Me.txtFechaRetiroHasta.Visible = False
            Me.txtFechaRetiroHasta.Enabled = False

            Me.cboPeriodoFechaRetiro.Value = Null
            Me.cboPeriodoFechaRetiro.Visible = False
            Me.cboPeriodoFechaRetiro.Enabled = False

        Case 2   ' Entre dos fechas
            Me.txtFechaRetiroUnica.Value = Null
            Me.txtFechaRetiroUnica.Visible = False
            Me.txtFechaRetiroUnica.Enabled = False

            Me.txtFechaRetiroDesde.Visible = True
            Me.txtFechaRetiroDesde.Enabled = True

            Me.txtFechaRetiroHasta.Visible = True
            Me.txtFechaRetiroHasta.Enabled = True

            Me.cboPeriodoFechaRetiro.Value = Null
            Me.cboPeriodoFechaRetiro.Visible = False
            Me.cboPeriodoFechaRetiro.Enabled = False

        Case 3   ' Periodo rápido
            Me.txtFechaRetiroUnica.Value = Null
            Me.txtFechaRetiroUnica.Visible = False
            Me.txtFechaRetiroUnica.Enabled = False

            Me.txtFechaRetiroDesde.Value = Null
            Me.txtFechaRetiroDesde.Visible = False
            Me.txtFechaRetiroDesde.Enabled = False

            Me.txtFechaRetiroHasta.Value = Null
            Me.txtFechaRetiroHasta.Visible = False
            Me.txtFechaRetiroHasta.Enabled = False

            Me.cboPeriodoFechaRetiro.Visible = True
            Me.cboPeriodoFechaRetiro.Enabled = True
    End Select

End Sub

Private Sub btnExportarExcel_Click()
    On Error GoTo ManejoErrores

    Dim xlApp As Object
    Dim rutaArchivo As Variant
    Dim db As DAO.Database
    Dim strSQL As String
    Dim nombreTablaTemp As String

    nombreTablaTemp = "tbl_temporal_exportacion_" & Format(Now(), "yyyymmddhhmmss")

    ' 1. Crear instancia de Excel para el diálogo (no visible)
    Set xlApp = CreateObject("Excel.Application")
    Set db = CurrentDb

    ' 2. Armar el SQL según haya o no filtro en el subformulario
    If Me.sfm_vista_informe_colaboradores.Form.FilterOn Then
        ' Hay filtro: lo usamos en el WHERE
        strSQL = "SELECT * INTO " & nombreTablaTemp & _
                 " FROM vista_informe_colaboradores WHERE " & _
                 Me.sfm_vista_informe_colaboradores.Form.Filter
    Else
        ' Sin filtro: exporta todo
        strSQL = "SELECT * INTO " & nombreTablaTemp & _
                 " FROM vista_informe_colaboradores"
    End If

    ' Crear la tabla temporal con los datos a exportar
    db.Execute strSQL, dbFailOnError

    ' 3. Mostrar cuadro de diálogo "Guardar como"
    rutaArchivo = xlApp.GetSaveAsFilename( _
        InitialFileName:="Informe_Colaboradores_" & Format(Now(), "yyyymmdd_hhmmss") & ".xlsx", _
        FileFilter:="Archivos de Excel (*.xlsx), *.xlsx", _
        Title:="Guardar Informe de Colaboradores")

    ' 4. Verificar si el usuario canceló
    If VarType(rutaArchivo) = vbBoolean And rutaArchivo = False Then
        MsgBox "Exportación cancelada por el usuario.", vbInformation
        GoTo Limpieza
    End If

    ' 5. Exportar la tabla temporal a Excel
    DoCmd.TransferSpreadsheet _
        TransferType:=acExport, _
        SpreadsheetType:=acSpreadsheetTypeExcel12Xml, _
        TableName:=nombreTablaTemp, _
        FileName:=rutaArchivo, _
        HasFieldNames:=True

    MsgBox "Los datos se han exportado correctamente a:" & vbCrLf & rutaArchivo, _
           vbInformation, "Exportación Completada"

    GoTo Limpieza

ManejoErrores:
    MsgBox "Error en la exportación: " & Err.Description, vbCritical, "Error"

Limpieza:
    On Error Resume Next
    ' Borrar tabla temporal
    If Not db Is Nothing Then
        db.Execute "DROP TABLE " & nombreTablaTemp
    End If
    ' Cerrar Excel
    If Not xlApp Is Nothing Then xlApp.Quit
    Set xlApp = Nothing
    Set db = Nothing
    On Error GoTo 0
End Sub

' Aplica la lógica según el usuario vaya seleccionando una opción

Private Sub grpFiltroFechaIngreso_AfterUpdate()
    ActualizarControlesFechaIngreso
End Sub

' Aplica la lógica según el usuario vaya seleccionando una opción

Private Sub grpFiltroFechaRetiro_AfterUpdate()
    ActualizarControlesFechaRetiro
End Sub

' Carga de formulario
Private Sub Form_Load()
    ' Asegura valor por defecto en opciones fecha ingreso
    If IsNull(Me.grpFiltroFechaIngreso) Then
        Me.grpFiltroFechaIngreso = 1
    End If
    ActualizarControlesFechaIngreso
    
    ' Asegura valor por defecto en opciones fecha retiro
    If IsNull(Me.grpFiltroFechaRetiro) Then
        Me.grpFiltroFechaRetiro = 1
    End If
    ActualizarControlesFechaRetiro
    
    ' Oculatar columnas de fecha_retiro y motivo
    ActualizarVisibilidadColumnas
    
    ' Calcular empleados actuales
    ActualizarTotalEmpleadosActuales
    
End Sub

' Lógica de aplicacioón de filtros para el reporte de planta en el subformulario
Private Sub btnAplicarFiltros_Click()

    '=================================================
    '  Filtros por FECHA_INGRESO (grpFiltroFechaIngreso)
    '=================================================

    Dim strFiltro As String
    Dim dDesde As Date
    Dim dHasta As Date

    '-------------------------------------------------
    ' 1) Filtro por fecha_ingreso - Opción 1: Fecha específica
    '-------------------------------------------------
    If Me.grpFiltroFechaIngreso = 1 Then
        If Not IsNull(Me.txtFechaIngresoUnica) Then
            If strFiltro <> "" Then
                strFiltro = strFiltro & " AND "
            End If

            strFiltro = strFiltro & "fecha_ingreso = #" & _
                        Format(Me.txtFechaIngresoUnica, "mm\/dd\/yyyy") & "#"
        End If
    End If

    '-------------------------------------------------
    ' 2) Filtro por fecha_ingreso - Opción 2: Entre dos fechas
    '-------------------------------------------------
    If Me.grpFiltroFechaIngreso = 2 Then

        'Si alguno de los dos está vacío, no se aplica filtro
        If Not IsNull(Me.txtFechaIngresoDesde) And Not IsNull(Me.txtFechaIngresoHasta) Then

            dDesde = Me.txtFechaIngresoDesde
            dHasta = Me.txtFechaIngresoHasta

            'Validar rango
            If dHasta < dDesde Then
                'Limpiar controles y avisar al usuario
                Me.txtFechaIngresoDesde = Null
                Me.txtFechaIngresoHasta = Null
                MsgBox "La fecha final no puede ser anterior a la fecha inicial. " & _
                       "Ingrese un rango de fechas válido.", vbExclamation, "Rango de fechas inválido"
            Else
                'Rango válido: construir filtro
                If strFiltro <> "" Then
                    strFiltro = strFiltro & " AND "
                End If

                strFiltro = strFiltro & "fecha_ingreso BETWEEN #" & _
                            Format(dDesde, "mm\/dd\/yyyy") & "# AND #" & _
                            Format(dHasta, "mm\/dd\/yyyy") & "#"
            End If
        End If

    End If

    '-------------------------------------------------
    ' 3) Filtro por fecha_ingreso - Opción 3: Periodo rápido
    '     cboPeriodoFechaIngreso: 'Todos';'Hoy';'Este mes';'Mes anterior';'Vacios'
    '-------------------------------------------------
    If Me.grpFiltroFechaIngreso = 3 Then
        If Not IsNull(Me.cboPeriodoFechaIngreso) Then

            Select Case Me.cboPeriodoFechaIngreso

                Case "Todos"
                    'No agrega condición: muestra todos los registros (sin filtro adicional por fecha_ingreso)

                Case "Hoy"
                    If strFiltro <> "" Then strFiltro = strFiltro & " AND "
                    strFiltro = strFiltro & "fecha_ingreso = Date()"

                Case "Este mes"
                    If strFiltro <> "" Then strFiltro = strFiltro & " AND "
                    strFiltro = strFiltro & _
                        "Year(fecha_ingreso) = Year(Date()) " & _
                        "AND Month(fecha_ingreso) = Month(Date())"

                Case "Mes anterior"
                    If strFiltro <> "" Then strFiltro = strFiltro & " AND "
                    strFiltro = strFiltro & _
                        "Year(fecha_ingreso) = Year(DateAdd('m', -1, Date())) " & _
                        "AND Month(fecha_ingreso) = Month(DateAdd('m', -1, Date()))"

                Case "Vacios"
                    If strFiltro <> "" Then strFiltro = strFiltro & " AND "
                    strFiltro = strFiltro & "fecha_ingreso IS NULL"

            End Select

        End If
    End If
    
    
    '=================================================
    '  Filtros por FECHA_RETIRO (grpFiltroFechaRetiro)
    '=================================================

    Dim dRetDesde As Date
    Dim dRetHasta As Date

    '---------------------------------------------
    ' 1) Opción 1: Fecha específica (txtFechaRetiroUnica)
    '---------------------------------------------
    If Me.grpFiltroFechaRetiro = 1 Then
        If Not IsNull(Me.txtFechaRetiroUnica) Then
            If strFiltro <> "" Then
                strFiltro = strFiltro & " AND "
            End If

            strFiltro = strFiltro & "fecha_retiro = #" & _
                        Format(Me.txtFechaRetiroUnica, "mm\/dd\/yyyy") & "#"
        End If
    End If

    '---------------------------------------------
    ' 2) Opción 2: Entre dos fechas
    '    (txtFechaRetiroDesde, txtFechaRetiroHasta)
    '---------------------------------------------
    If Me.grpFiltroFechaRetiro = 2 Then

        If Not IsNull(Me.txtFechaRetiroDesde) And Not IsNull(Me.txtFechaRetiroHasta) Then

            dRetDesde = Me.txtFechaRetiroDesde
            dRetHasta = Me.txtFechaRetiroHasta

            If dRetHasta < dRetDesde Then
                Me.txtFechaRetiroDesde = Null
                Me.txtFechaRetiroHasta = Null
                MsgBox "La fecha final de retiro no puede ser anterior a la fecha inicial. " & _
                       "Ingrese un rango de fechas de retiro válido.", _
                       vbExclamation, "Rango de fechas de retiro inválido"
            Else
                If strFiltro <> "" Then
                    strFiltro = strFiltro & " AND "
                End If

                strFiltro = strFiltro & "fecha_retiro BETWEEN #" & _
                            Format(dRetDesde, "mm\/dd\/yyyy") & "# AND #" & _
                            Format(dRetHasta, "mm\/dd\/yyyy") & "#"
            End If
        End If

    End If

    '---------------------------------------------
    ' 3) Opción 3: Periodo rápido (cboPeriodoFechaRetiro)
    '     Valores: 'Todos';'Hoy';'Este mes';'Mes anterior';'Vacios'
    '---------------------------------------------
    If Me.grpFiltroFechaRetiro = 3 Then
        If Not IsNull(Me.cboPeriodoFechaRetiro) Then

            Select Case Me.cboPeriodoFechaRetiro

                Case "Todos"
                    ' Sin condición extra para fecha_retiro

                Case "Hoy"
                    If strFiltro <> "" Then strFiltro = strFiltro & " AND "
                    strFiltro = strFiltro & "fecha_retiro = Date()"

                Case "Este mes"
                    If strFiltro <> "" Then strFiltro = strFiltro & " AND "
                    strFiltro = strFiltro & _
                        "Year(fecha_retiro) = Year(Date()) " & _
                        "AND Month(fecha_retiro) = Month(Date())"

                Case "Mes anterior"
                    If strFiltro <> "" Then strFiltro = strFiltro & " AND "
                    strFiltro = strFiltro & _
                        "Year(fecha_retiro) = Year(DateAdd('m', -1, Date())) " & _
                        "AND Month(fecha_retiro) = Month(DateAdd('m', -1, Date()))"

                Case "Vacios"
                    If strFiltro <> "" Then strFiltro = strFiltro & " AND "
                    strFiltro = strFiltro & "fecha_retiro IS NULL"

            End Select

        End If
    End If
    
    
    '=================================================
    '  Filtros por TEXTO (Id CC y Nombre)
    '=================================================

    '--- txtFiltroIdCC sobre id_cc ---
    If Not IsNull(Me.txtFiltroIdCC) And Me.txtFiltroIdCC <> "" Then
        If strFiltro <> "" Then
            strFiltro = strFiltro & " AND "
        End If

        strFiltro = strFiltro & "id_cc LIKE '*" & _
                    Replace(Me.txtFiltroIdCC, "'", "''") & "*'"
    End If

    '--- txtFiltroNombre sobre nombre_completo ---
    If Not IsNull(Me.txtFiltroNombre) And Me.txtFiltroNombre <> "" Then
        If strFiltro <> "" Then
            strFiltro = strFiltro & " AND "
        End If

        strFiltro = strFiltro & "nombre_completo LIKE '*" & _
                    Replace(Me.txtFiltroNombre, "'", "''") & "*'"
    End If
    
       
    '=================================================
    '  Filtros por COMBOBOX
    '=================================================

    '--- cboFiltroCargo sobre campo cargo (BoundColumn = 2) ---
    If Not IsNull(Me.cboFiltroCargo) And Me.cboFiltroCargo <> "" Then
        If strFiltro <> "" Then
            strFiltro = strFiltro & " AND "
        End If
        strFiltro = strFiltro & "cargo = '" & _
                    Replace(Me.cboFiltroCargo, "'", "''") & "'"
    End If

    '--- cboFiltroCiudad sobre campo ciudad (BoundColumn = 2) ---
    If Not IsNull(Me.cboFiltroCiudad) And Me.cboFiltroCiudad <> "" Then
        If strFiltro <> "" Then
            strFiltro = strFiltro & " AND "
        End If
        strFiltro = strFiltro & "ciudad = '" & _
                    Replace(Me.cboFiltroCiudad, "'", "''") & "'"
    End If

    '--- cboFiltroEstatus sobre campo estatus_colaborador ---
    If Not IsNull(Me.cboFiltroEstatus) And Me.cboFiltroEstatus <> "" Then
        If strFiltro <> "" Then
            strFiltro = strFiltro & " AND "
        End If
        strFiltro = strFiltro & "estatus_colaborador = '" & _
                    Replace(Me.cboFiltroEstatus, "'", "''") & "'"
    End If
    
    '--- chkExcluirRetirados: excluye estatus_colaborador = "Retirado" ---
    If Me.chkExcluirRetirados = True Then
        If strFiltro <> "" Then
            strFiltro = strFiltro & " AND "
        End If
        strFiltro = strFiltro & "estatus_colaborador <> 'Retirado'"
    End If

    '--- cboFiltroCentroCosto sobre campo centro_costo (BoundColumn = 2) ---
    If Not IsNull(Me.cboFiltroCentroCosto) And Me.cboFiltroCentroCosto <> "" Then
        If strFiltro <> "" Then
            strFiltro = strFiltro & " AND "
        End If
        strFiltro = strFiltro & "centro_costo = '" & _
                    Replace(Me.cboFiltroCentroCosto, "'", "''") & "'"
    End If


    'Aplicar el filtro al subformulario
    With Me.sfm_vista_informe_colaboradores.Form
        .Filter = strFiltro
        .FilterOn = (strFiltro <> "")
    End With
    
    ' ajustar la visualizacion de las columnas fecha_retiro y motivo
    ActualizarVisibilidadColumnas

End Sub


' Lógica Botón limpiar Filtros
Private Sub btnLimpiarFiltros_Click()

    '---------------------------
    ' 1) Resetear controles fecha ingreso
    '---------------------------
    Me.grpFiltroFechaIngreso = 1
    Me.txtFechaIngresoUnica = Null
    Me.txtFechaIngresoDesde = Null
    Me.txtFechaIngresoHasta = Null
    Me.cboPeriodoFechaIngreso = Null
    ActualizarControlesFechaIngreso

    '---------------------------
    ' 2) Resetear controles fecha retiro
    '---------------------------
    Me.grpFiltroFechaRetiro = 1
    Me.txtFechaRetiroUnica = Null
    Me.txtFechaRetiroDesde = Null
    Me.txtFechaRetiroHasta = Null
    Me.cboPeriodoFechaRetiro = Null
    ActualizarControlesFechaRetiro

    '---------------------------
    ' 3) Resetear filtros de texto / combos
    '   (ajusta a los nombres reales de tus controles)
    '---------------------------
    Me.txtFiltroIdCC = Null
    Me.txtFiltroNombre = Null
    Me.cboFiltroEstatus = Null
    Me.cboFiltroCiudad = Null
    Me.cboFiltroCentroCosto = Null
    Me.cboFiltroCargo = Null
    Me.chkExcluirRetirados = False

    '---------------------------
    ' 4) Quitar filtro y refrescar subformulario
    '---------------------------
    With Me.sfm_vista_informe_colaboradores.Form
        .FilterOn = False
        .Filter = ""
        .Requery
    End With
    
     ActualizarVisibilidadColumnas
    
    
    '---------------------------
    ' 5) recalcular el número de empleados de la empresa
    '---------------------------
    With Me.sfm_vista_informe_colaboradores.Form
        .FilterOn = False
        .Filter = ""
        .Requery          'requery adicional para mantener datos actualizados [web:120]
    End With

    'Actualizar total de empleados actuales
    ActualizarTotalEmpleadosActuales


End Sub

' Convertir a Mayúsculas el nombre ingresado para el filtrado
Private Sub txtFiltroNombre_AfterUpdate()

    If Not IsNull(Me.txtFiltroNombre) Then
        Me.txtFiltroNombre = UCase(Me.txtFiltroNombre)
    End If

End Sub

' Función para calcular los Empleados Actuales
Private Sub ActualizarTotalEmpleadosActuales()

    Dim lngTotal As Long
    Dim lngRetirados As Long
    Dim lngActuales As Long

    lngTotal = DCount("*", "vista_informe_colaboradores")
    lngRetirados = DCount("*", "vista_informe_colaboradores", "estatus_colaborador = 'Retirado'")

    lngActuales = lngTotal - lngRetirados

    Me.txtTotalEmpleadosActuales = lngActuales

End Sub

' -------------------------------------------------------------------------
' CONTROL DINÁMICO DE COLUMNAS (Visualización)
' Oculta fecha_retiro y motivo si no se está filtrando explícitamente por 'Retirado'
' -------------------------------------------------------------------------
Private Sub ActualizarVisibilidadColumnas()
    Dim mostrarRetiro As Boolean
    
    ' Por defecto ocultamos
    mostrarRetiro = False
    
    ' Lógica: Solo mostramos si seleccionó 'Retirado' Y NO ha marcado 'Excluir Retirados'
    If Nz(Me.cboFiltroEstatus, "") = "Retirado" Then
        If Me.chkExcluirRetirados = False Then
            mostrarRetiro = True
        End If
    End If
    
    ' Aplicar al subformulario (Hoja de Datos)
    On Error Resume Next
    With Me.sfm_vista_informe_colaboradores.Form
        ' El valor True en ColumnHidden OCULTA la columna.
        .Controls("fecha_retiro").ColumnHidden = Not mostrarRetiro
        .Controls("motivo").ColumnHidden = Not mostrarRetiro
    End With
    On Error GoTo 0
End Sub



