VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Informe_Planta_PYP"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
' ====== DECLARACIONES AL INICIO DEL MÓDULO (antes de cualquier Sub) ======
Private Declare PtrSafe Function FindWindow Lib "user32" Alias "FindWindowA" _
    (ByVal lpClassName As String, ByVal lpWindowName As String) As LongPtr

Private Declare PtrSafe Function SetForegroundWindow Lib "user32" _
    (ByVal hwnd As LongPtr) As Long

' Lógica de Seleccion del control de Opciones para Fecha Ingreso Colaborador

Private Sub ActualizarControlesFechaIngreso()

    Select Case Me.grpFiltroFechaIngreso
        Case 1   ' Fecha específica
            ' Activar único
            Me.txtFechaIngresoUnica.Visible = True
            Me.txtFechaIngresoUnica.Enabled = True

            ' Desactivar y limpiar rango
            Me.txtFechaIngresoDesde.value = Null
            Me.txtFechaIngresoDesde.Visible = False
            Me.txtFechaIngresoDesde.Enabled = False

            Me.txtFechaIngresoHasta.value = Null
            Me.txtFechaIngresoHasta.Visible = False
            Me.txtFechaIngresoHasta.Enabled = False

            ' Desactivar y limpiar periodo
            Me.cboPeriodoFechaIngreso.value = Null
            Me.cboPeriodoFechaIngreso.Visible = False
            Me.cboPeriodoFechaIngreso.Enabled = False

        Case 2   ' Entre dos fechas
            ' Desactivar y limpiar único
            Me.txtFechaIngresoUnica.value = Null
            Me.txtFechaIngresoUnica.Visible = False
            Me.txtFechaIngresoUnica.Enabled = False

            ' Activar rango
            Me.txtFechaIngresoDesde.Visible = True
            Me.txtFechaIngresoDesde.Enabled = True

            Me.txtFechaIngresoHasta.Visible = True
            Me.txtFechaIngresoHasta.Enabled = True

            ' Desactivar y limpiar periodo
            Me.cboPeriodoFechaIngreso.value = Null
            Me.cboPeriodoFechaIngreso.Visible = False
            Me.cboPeriodoFechaIngreso.Enabled = False

        Case 3   ' Periodo rápido
            ' Desactivar y limpiar único
            Me.txtFechaIngresoUnica.value = Null
            Me.txtFechaIngresoUnica.Visible = False
            Me.txtFechaIngresoUnica.Enabled = False

            ' Desactivar y limpiar rango
            Me.txtFechaIngresoDesde.value = Null
            Me.txtFechaIngresoDesde.Visible = False
            Me.txtFechaIngresoDesde.Enabled = False

            Me.txtFechaIngresoHasta.value = Null
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

            Me.txtFechaRetiroDesde.value = Null
            Me.txtFechaRetiroDesde.Visible = False
            Me.txtFechaRetiroDesde.Enabled = False

            Me.txtFechaRetiroHasta.value = Null
            Me.txtFechaRetiroHasta.Visible = False
            Me.txtFechaRetiroHasta.Enabled = False

            Me.cboPeriodoFechaRetiro.value = Null
            Me.cboPeriodoFechaRetiro.Visible = False
            Me.cboPeriodoFechaRetiro.Enabled = False

        Case 2   ' Entre dos fechas
            Me.txtFechaRetiroUnica.value = Null
            Me.txtFechaRetiroUnica.Visible = False
            Me.txtFechaRetiroUnica.Enabled = False

            Me.txtFechaRetiroDesde.Visible = True
            Me.txtFechaRetiroDesde.Enabled = True

            Me.txtFechaRetiroHasta.Visible = True
            Me.txtFechaRetiroHasta.Enabled = True

            Me.cboPeriodoFechaRetiro.value = Null
            Me.cboPeriodoFechaRetiro.Visible = False
            Me.cboPeriodoFechaRetiro.Enabled = False

        Case 3   ' Periodo rápido
            Me.txtFechaRetiroUnica.value = Null
            Me.txtFechaRetiroUnica.Visible = False
            Me.txtFechaRetiroUnica.Enabled = False

            Me.txtFechaRetiroDesde.value = Null
            Me.txtFechaRetiroDesde.Visible = False
            Me.txtFechaRetiroDesde.Enabled = False

            Me.txtFechaRetiroHasta.value = Null
            Me.txtFechaRetiroHasta.Visible = False
            Me.txtFechaRetiroHasta.Enabled = False

            Me.cboPeriodoFechaRetiro.Visible = True
            Me.cboPeriodoFechaRetiro.Enabled = True
    End Select

End Sub

Private Sub btnExportarExcel_Click()
    On Error GoTo ManejoErrores

    Dim xlApp As Object
    Dim xlWb As Object
    Dim xlWsActivos As Object
    Dim xlWsRetirados As Object
    Dim rutaArchivo As Variant
    Dim db As DAO.Database
    Dim strFiltroBase As String
    Dim strSQLActivos As String
    Dim strSQLRetirados As String
    Dim nombreTablaActivos As String
    Dim nombreTablaRetirados As String
    Dim rutaTempActivos As String
    Dim rutaTempRetirados As String
    Dim timestamp As String

    timestamp = Format(Now(), "yyyymmddhhmmss")
    nombreTablaActivos = "tbl_temp_activos_" & timestamp
    nombreTablaRetirados = "tbl_temp_retirados_" & timestamp

    ' 1. Crear instancia de Excel para el diálogo
    Set xlApp = CreateObject("Excel.Application")
    Set db = CurrentDb

    ' 2. Obtener el filtro base del subformulario
    If Me.sfm_vista_planta_pyp.Form.FilterOn Then
        strFiltroBase = Me.sfm_vista_planta_pyp.Form.Filter
    Else
        strFiltroBase = "1=1"
    End If

    ' 3. Crear SQL para Activos
    strSQLActivos = "SELECT * INTO " & nombreTablaActivos & _
                    " FROM vista_planta_pyp WHERE (" & strFiltroBase & ")" & _
                    " AND (estatus_colaborador <> 'Retirado' OR estatus_colaborador IS NULL)"

    ' 4. Crear SQL para Retirados
    strSQLRetirados = "SELECT * INTO " & nombreTablaRetirados & _
                      " FROM vista_planta_pyp WHERE (" & strFiltroBase & ")" & _
                      " AND estatus_colaborador = 'Retirado'"

    ' 5. Ejecutar consultas
    db.Execute strSQLActivos, dbFailOnError
    db.Execute strSQLRetirados, dbFailOnError

    ' 6. Mostrar diálogo "Guardar como"
    ' Hacer visible Excel temporalmente para que el diálogo aparezca al frente
    xlApp.Visible = True
    
    rutaArchivo = xlApp.GetSaveAsFilename( _
        InitialFileName:="Informe_Planta_PYP_" & Format(Now(), "yyyymmdd_hhmmss") & ".xlsx", _
        FileFilter:="Archivos de Excel (*.xlsx), *.xlsx", _
        Title:="Guardar Informe Planta PYP")
        
    ' Traer el diálogo al frente usando API de Windows
    Dim hwnd As LongPtr
    hwnd = FindWindow(vbNullString, "Guardar como")
    If hwnd <> 0 Then SetForegroundWindow hwnd
    
    ' Ocultar Excel nuevamente
    xlApp.Visible = False

    ' 7. Verificar cancelación
    If VarType(rutaArchivo) = vbBoolean And rutaArchivo = False Then
        MsgBox "Exportación cancelada por el usuario.", vbInformation
        GoTo Limpieza
    End If

    ' 8. Crear rutas temporales
    rutaTempActivos = Environ("TEMP") & "\temp_activos_pyp_" & timestamp & ".xlsx"
    rutaTempRetirados = Environ("TEMP") & "\temp_retirados_pyp_" & timestamp & ".xlsx"

    ' 9. Exportar ambas tablas a archivos temporales
    DoCmd.TransferSpreadsheet _
        TransferType:=acExport, _
        SpreadsheetType:=acSpreadsheetTypeExcel12Xml, _
        TableName:=nombreTablaActivos, _
        FileName:=rutaTempActivos, _
        HasFieldNames:=True

    DoCmd.TransferSpreadsheet _
        TransferType:=acExport, _
        SpreadsheetType:=acSpreadsheetTypeExcel12Xml, _
        TableName:=nombreTablaRetirados, _
        FileName:=rutaTempRetirados, _
        HasFieldNames:=True

    ' 10. Crear libro final con dos pestañas
    xlApp.DisplayAlerts = False
    
    Set xlWb = xlApp.Workbooks.Open(rutaTempActivos)
    Set xlWsActivos = xlWb.Worksheets(1)
    xlWsActivos.Name = "Activos"
    
    ' ****************************************************
    ' AQUÍ AGREGAR: ELIMINAR COLUMNAS fecha_retiro y motivo
    ' ****************************************************
    Dim colFechaRetiro As Integer
    Dim colMotivo As Integer
    Dim j As Integer
    
    colFechaRetiro = 0
    colMotivo = 0
    
    ' Buscar columnas
    For j = 1 To xlWsActivos.UsedRange.Columns.Count
        If xlWsActivos.Cells(1, j).value = "fecha_retiro" Then
            colFechaRetiro = j
        End If
        If xlWsActivos.Cells(1, j).value = "motivo" Then
            colMotivo = j
        End If
    Next j
    
    ' Eliminar columnas (mayor índice primero)
    If colMotivo > colFechaRetiro And colMotivo > 0 Then
        xlWsActivos.Columns(colMotivo).Delete
        xlWsActivos.Columns(colFechaRetiro).Delete
    ElseIf colFechaRetiro > colMotivo And colFechaRetiro > 0 Then
        xlWsActivos.Columns(colFechaRetiro).Delete
        xlWsActivos.Columns(colMotivo).Delete
    End If
    ' ****************************************************

    ' 11. Formatear hoja "Activos"
    Call FormatearHojaExcel(xlWsActivos, xlApp)

    ' 12. Importar Retirados
    Dim xlWbRetirados As Object
    Set xlWbRetirados = xlApp.Workbooks.Open(rutaTempRetirados)
    
    xlWbRetirados.Worksheets(1).Copy After:=xlWb.Worksheets(xlWb.Worksheets.Count)
    
    Set xlWsRetirados = xlWb.Worksheets(xlWb.Worksheets.Count)
    xlWsRetirados.Name = "Retirados"
    
    Call FormatearHojaExcel(xlWsRetirados, xlApp)
    
    xlWbRetirados.Close False
    Set xlWbRetirados = Nothing

    ' 13. Guardar archivo final
    xlWb.SaveAs rutaArchivo
    xlWb.Close
    xlApp.DisplayAlerts = True

    ' 14. Limpiar archivos temporales
    On Error Resume Next
    Kill rutaTempActivos
    Kill rutaTempRetirados
    On Error GoTo 0

    MsgBox "Los datos se han exportado correctamente a:" & vbCrLf & rutaArchivo, _
           vbInformation, "Exportación Completada"

    GoTo Limpieza

ManejoErrores:
    MsgBox "Error en la exportación: " & Err.Description & " (Código: " & Err.Number & ")", _
           vbCritical, "Error"

Limpieza:
    On Error Resume Next
    If Not db Is Nothing Then
        db.Execute "DROP TABLE " & nombreTablaActivos
        db.Execute "DROP TABLE " & nombreTablaRetirados
    End If
    Kill rutaTempActivos
    Kill rutaTempRetirados
    If Not xlWb Is Nothing Then xlWb.Close False
    If Not xlWbRetirados Is Nothing Then xlWbRetirados.Close False
    If Not xlApp Is Nothing Then
        xlApp.DisplayAlerts = True
        xlApp.Quit
    End If
    Set xlWsRetirados = Nothing
    Set xlWsActivos = Nothing
    Set xlWbRetirados = Nothing
    Set xlWb = Nothing
    Set xlApp = Nothing
    Set db = Nothing
    On Error GoTo 0
End Sub

Private Sub FormatearHojaExcel(ws As Object, xlApp As Object)
    On Error Resume Next
    
    With ws
        .Rows(1).Font.Bold = True
        .Rows(1).Font.Color = RGB(255, 255, 255)
        .Rows(1).Interior.Color = RGB(102, 126, 234)
        .Columns.AutoFit
        
        If .UsedRange.Rows.Count > 0 Then
            .UsedRange.AutoFilter
        End If
        
        .Rows(1).HorizontalAlignment = -4108 ' xlCenter
        
        .Rows(2).Activate
        xlApp.ActiveWindow.FreezePanes = True
    End With
    
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
    With Me.sfm_vista_planta_pyp.Form
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
    With Me.sfm_vista_planta_pyp.Form
        .FilterOn = False
        .Filter = ""
        .Requery
    End With
    
     ActualizarVisibilidadColumnas
    
    
    '---------------------------
    ' 5) recalcular el número de empleados de la empresa
    '---------------------------
    With Me.sfm_vista_planta_pyp.Form
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
    With Me.sfm_vista_planta_pyp.Form
        ' El valor True en ColumnHidden OCULTA la columna.
        .Controls("fecha_retiro").ColumnHidden = Not mostrarRetiro
        .Controls("motivo").ColumnHidden = Not mostrarRetiro
    End With
    On Error GoTo 0
End Sub



