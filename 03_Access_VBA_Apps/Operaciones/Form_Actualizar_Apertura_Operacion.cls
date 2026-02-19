VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Actualizar_Apertura_Operacion"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
    Option Compare Database

'----------------------------
' Función que arma la condición WHERE común para filtros de fecha y estación
'----------------------------
Private Function ObtenerCondicionWhere() As String
    Dim strWhere As String
    Dim strFecha As String
    Dim baseSeleccionada As Variant
    
    strWhere = ""
    
    ' 1) Filtrar por fecha (Access acepta literales #yyyy/mm/dd#)
    If Not IsNull(Me.txtFecha) And Me.txtFecha <> "" Then
        strFecha = "#" & Format(Me.txtFecha, "yyyy\/mm\/dd") & "#"
        strWhere = "O.fecha = " & strFecha
    End If
    
    ' 2) Filtrar por estación (BD.base_id)
    baseSeleccionada = Me.cmbEstacion.Value
    If Not IsNull(baseSeleccionada) And baseSeleccionada <> "" Then
        If strWhere <> "" Then strWhere = strWhere & " AND "
        strWhere = strWhere & "BD.base_id = " & baseSeleccionada
    End If
    
    ObtenerCondicionWhere = strWhere
End Function

'----------------------------
' Función para calcular horas reales en formato decimal (considerando cruce de día)
'----------------------------
Private Function CalcularHorasReales(horaInicio As Date, horaFinal As Date) As Double
    Dim hInicio As Double
    Dim hFinal As Double
    Dim diffHoras As Double

    ' Extraer solo la parte decimal (hora) de las fechas
    hInicio = horaInicio - Int(horaInicio)
    hFinal = horaFinal - Int(horaFinal)

    If hFinal <= hInicio Then
        diffHoras = (hFinal + 1) - hInicio  ' Suma un día si cruza medianoche
    Else
        diffHoras = hFinal - hInicio
    End If

    CalcularHorasReales = diffHoras * 24
End Function

'----------------------------
' Función para calcular horas no operativas según lógica Excel
'----------------------------
Private Function CalcularHorasNoOperativas(horasReales As Double) As Double
    If horasReales < 8 Then
        CalcularHorasNoOperativas = 0
    ElseIf horasReales < 9 Then
        CalcularHorasNoOperativas = horasReales - 8
    Else
        CalcularHorasNoOperativas = 1
    End If
End Function

'----------------------------
' Actualizar ComboBox de placas según filtros
' (solo operaciones abiertas: hora_final IS NULL AND km_final IS NULL)
'----------------------------
Private Sub ActualizarComboPlacas()
    Dim strSQL     As String
    Dim baseWhere  As String
    Dim dynWhere   As String
    
    ' 1) Filtro base: solo operaciones abiertas
    baseWhere = "O.hora_final IS NULL AND O.km_final IS NULL"
    
    ' 2) Agregar filtros de fecha/estación
    dynWhere = ObtenerCondicionWhere()
    If dynWhere <> "" Then
        baseWhere = baseWhere & " AND " & dynWhere
    End If
    
    ' 3) Construir el SELECT DISTINCT para el combo de placas
    strSQL = _
      "SELECT DISTINCT O.placa " & _
      "FROM (vista_operaciones AS O " & _
      "INNER JOIN vista_bases_deprisa AS BD ON O.estacion = BD.base_id) " & _
      "INNER JOIN vista_sectores_deprisa AS SD ON O.sector = SD.sector " & _
      "WHERE " & baseWhere & " " & _
      "ORDER BY O.placa;"
    
    Me.cmbPlacaVehiculo.RowSource = strSQL
    Me.cmbPlacaVehiculo.Requery
End Sub

'----------------------------
' Filtrar ListBox con placas, fecha y base
' sobre la consulta base que ya impone hora_final IS NULL y km_final IS NULL
'----------------------------
Private Sub FiltrarListBoxOperaciones()
    Dim strSQL            As String
    Dim baseWhere         As String
    Dim dynWhere          As String
    Dim placaSeleccionada As String

    ' 1) Filtro base: solo operaciones abiertas
    baseWhere = "O.hora_final IS NULL AND O.km_final IS NULL"
    
    ' 2) Agregar filtros de fecha/estación
    dynWhere = ObtenerCondicionWhere()
    If dynWhere <> "" Then
        baseWhere = baseWhere & " AND " & dynWhere
    End If

    ' 3) Agregar filtro de placa si existe
    placaSeleccionada = Nz(Me.cmbPlacaVehiculo.Value, "")
    If placaSeleccionada <> "" Then
        baseWhere = baseWhere & " AND O.placa = '" & Replace(placaSeleccionada, "'", "''") & "'"
    End If

    ' 4) Construir la consulta SQL (máximo 7 líneas)
    strSQL = "SELECT O.operacion_id, O.fecha, BD.bases, O.vehiculo, O.placa, O.sector, SD.contrato, O.nombre_ruta, O.remesa, O.manifiesto " & _
             "FROM (vista_operaciones AS O INNER JOIN vista_bases_deprisa AS BD ON O.estacion = BD.base_id) INNER JOIN vista_sectores_deprisa AS SD ON O.sector = SD.sector " & _
             "WHERE " & baseWhere & " ORDER BY O.fecha DESC;"

    Me.lstOperaciones.RowSource = strSQL
    Me.lstOperaciones.Requery
End Sub

'----------------------------
' Botón "Borrar": limpia todos los campos del formulario
'----------------------------
Private Sub BTN_Borrar_Click()
    Call LimpiarCampos

    ' --- Recupera y fija SIEMPRE la estación de la sesión actual ---
    Dim rsSesion As DAO.Recordset
    Dim valorBase As Variant
    Set rsSesion = CurrentDb.OpenRecordset("SELECT base_actual FROM tbl_sesion_actual", dbOpenSnapshot)
    If Not rsSesion.EOF Then
        valorBase = rsSesion!base_actual
        If Not IsNull(valorBase) And valorBase <> "" Then
            Me.cmbEstacion.Value = valorBase
            Call cmbEstacion_AfterUpdate
        End If
    End If
    rsSesion.Close

    Me.txtFecha.Value = Date
    Call FiltrarListBoxOperaciones

    ' Resto igual (deshabilitar controles)
    Me.txtKmFinal.Enabled = False
    Me.cmbHorafinal.Enabled = False
    Me.txtDevoluciones.Enabled = False
    Me.txtRecolecciones.Enabled = False
    Me.txtRecoleccionesNoEfectivas.Enabled = False
End Sub

'----------------------------
' Botón "Guardar": llama al stored procedure para cerrar el despacho
'----------------------------
Private Sub BTN_Guardar_Click()
    On Error GoTo ErrHandler

    Dim operacionID As Variant
    Dim sql As String
    Dim usuarioActual As String
    Dim nuevaCantidadEnvios As Long
    Dim txtEnviosVal As Long
    Dim txtAdicionalVal As Long
    Dim rsOT As DAO.Recordset
    Dim jsonOTs As String

    ' Obtener el usuario actual usando la función global
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. El registro no se puede completar.", vbCritical
        Exit Sub
    End If

    ' Asegurar que el operacion_id esté seleccionado
    operacionID = Me.lstOperaciones.Column(0)
    If IsNull(operacionID) Or operacionID = "" Then
        MsgBox "Debe seleccionar una operación de despacho.", vbExclamation
        Exit Sub
    End If

    ' Validar que el subformulario tbl_ot_temporal tenga al menos una OT
    Set rsOT = Me!sub_tbl_ot_temporal.Form.RecordsetClone
    If rsOT.RecordCount = 0 Then
        MsgBox "Debe ingresar al menos una OT antes de guardar.", vbExclamation
        Exit Sub
    End If

    ' Validar campo txtEnviosAdicionales (debe ser numérico y obligatorio)
    If IsNull(Me.txtEnviosAdicionales) Or Trim(Me.txtEnviosAdicionales) = "" Or Not IsNumeric(Me.txtEnviosAdicionales) Then
        MsgBox "Debe ingresar un número válido en envíos adicionales.", vbExclamation
        Exit Sub
    End If

    ' Obtener valores numéricos (por defecto 0 si txtEnvios no tiene valor)
    txtEnviosVal = 0
    If Not IsNull(Me.txtEnvios) And Me.txtEnvios <> "" And IsNumeric(Me.txtEnvios) Then
        txtEnviosVal = CLng(Me.txtEnvios)
    End If
    txtAdicionalVal = CLng(Me.txtEnviosAdicionales)
    nuevaCantidadEnvios = txtEnviosVal + txtAdicionalVal

    ' Generar JSON de OTs (ejemplo: ["OT1","OT2"])
    jsonOTs = "["
    rsOT.MoveFirst
    Do Until rsOT.EOF
        jsonOTs = jsonOTs & """" & rsOT!numero_ot & """"
        rsOT.MoveNext
        If Not rsOT.EOF Then jsonOTs = jsonOTs & ","
    Loop
    jsonOTs = jsonOTs & "]"
    rsOT.Close

    ' Verificar y reconectar si es necesario
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con

    ' Llamado al stored procedure
    sql = "CALL actualizar_operacion_y_ots(" & operacionID & "," & nuevaCantidadEnvios & ",'" & Replace(jsonOTs, "'", "''") & "','" & Replace(usuarioActual, "'", "''") & "');"
    cnn.Execute sql

    ' Limpiar campos y actualizar controles
    Call LimpiarCampos
    Me.txtFecha.Value = Date
    Call FiltrarListBoxOperaciones
    Call RequeryAllDataControls(Me)
    MsgBox "Operación actualizada correctamente.", vbInformation
    
    Call LimpiarControlesOperaciones

    Exit Sub

ErrHandler:
    MsgBox "Error: " & Err.Number & " - " & Err.Description, vbCritical
End Sub

'----------------------------
' Al seleccionar un registro en ListBox, llenar campos detalle
'----------------------------
Private Sub lstOperaciones_AfterUpdate()
    Dim operacionID As Variant
    Dim rs          As DAO.Recordset
    Dim strSQL      As String

    operacionID = Me.lstOperaciones.Column(0)
    If IsNull(operacionID) Or operacionID = "" Then
        ' Limpiar campos si no hay selección
        Me.txtVehiculo = ""
        Me.txtPlaca = ""
        Me.txtHoraInicio = ""        ' Limpiamos sin validar
        Me.txtKmInicial = ""
        Me.txtEnvios = ""
        Me.lstOT.RowSource = ""
        Me.lstOT.Requery
        Exit Sub
    End If

    ' 1) Abrir recordset para traer datos del despacho seleccionado
    strSQL = "SELECT vehiculo, placa, hora_inicio, km_inicial, cantidad_envios " & _
             "FROM vista_operaciones WHERE operacion_id = " & operacionID & ";"
    Set rs = CurrentDb.OpenRecordset(strSQL, dbOpenSnapshot)

    If Not rs.EOF Then
        Me.txtVehiculo = rs!vehiculo
        Me.txtPlaca = rs!placa
        
        ' Convertir hora_inicio a Date sin validar cmbHorafinal
        If Not IsNull(rs!hora_inicio) And IsDate(rs!hora_inicio) Then
            Me.txtHoraInicio = CDate(rs!hora_inicio)
        Else
            Me.txtHoraInicio = Null
        End If

        Me.txtKmInicial = rs!km_inicial
        Me.txtEnvios = rs!cantidad_envios
    Else
        Me.txtVehiculo = ""
        Me.txtPlaca = ""
        Me.txtHoraInicio = Null
        Me.txtKmInicial = ""
        Me.txtEnvios = ""
    End If

    rs.Close
    Set rs = Nothing

    ' 2) Cargar las órdenes de trabajo relacionadas sin más validaciones
    strSQL = "SELECT numero_ot FROM vista_ordenes_trabajo_vehiculo " & _
             "WHERE operacion_id = " & operacionID & " ORDER BY numero_ot;"
    Me.lstOT.RowSource = strSQL
    Me.lstOT.Requery
End Sub

'----------------------------
' Eventos AfterUpdate para filtros que afectan ListBox y ComboBox
'----------------------------
Private Sub txtFecha_AfterUpdate()
    Call ActualizarComboPlacas
    Call FiltrarListBoxOperaciones
End Sub

Private Sub cmbEstacion_AfterUpdate()
    Call ActualizarComboPlacas
    Call FiltrarListBoxOperaciones
End Sub

Private Sub cmbPlacaVehiculo_AfterUpdate()
    Call FiltrarListBoxOperaciones
End Sub

'----------------------------
' Evento Form Load
'----------------------------
Private Sub Form_Load()
    Dim rsSesion As DAO.Recordset
    Dim valorBase As Variant

    Call LimpiarCampos

    ' --- Nuevo: Lee la base desde la sesión y la fija en cmbEstacion ---
    Set rsSesion = CurrentDb.OpenRecordset("SELECT base_actual FROM tbl_sesion_actual", dbOpenSnapshot)
    If Not rsSesion.EOF Then
        valorBase = rsSesion!base_actual
        If Not IsNull(valorBase) And valorBase <> "" Then
            Me.cmbEstacion.Value = valorBase
            ' Llama AfterUpdate manualmente para que todo filtro dependa de esta estación
            Call cmbEstacion_AfterUpdate
        End If
    End If
    rsSesion.Close

    Me.cmbEstacion.Locked = True ' Opcional: que el usuario no cambie estación

    Me.txtFecha.Value = Date ' O el valor predeterminado que prefieres
    Call ActualizarComboPlacas ' Opcional si cmbEstacion_AfterUpdate ya lo hace
    Call FiltrarListBoxOperaciones
    Call LimpiarControlesOperaciones
    
End Sub


'----------------------------
' Función para Limpiar Formulario
'----------------------------
Private Sub LimpiarCampos()
    ' Limpiar ComboBoxes
    
    Me.cmbPlacaVehiculo.Value = ""
    
    ' Limpiar ListBoxes
    Me.lstOperaciones.RowSource = ""
    Me.lstOT.RowSource = ""
    
    ' Limpiar TextBoxes
    Me.txtVehiculo = ""
    Me.txtPlaca = ""
    Me.txtHoraInicio = ""
    Me.txtKmInicial = ""
    Me.txtEnvios = ""
    
    ' No sobrescribir txtFecha aquí para no perder el filtro actual
End Sub

' Limpiar control de OT y de nuevos envíos
Private Sub LimpiarControlesOperaciones()
    On Error Resume Next

    ' 1. Limpiar el subformulario (eliminar todos los registros de la tabla temporal)
    CurrentDb.Execute "DELETE FROM tbl_ot_temporal", dbFailOnError
    Me.sub_tbl_ot_temporal.Form.Requery

    ' 2. Limpiar el textbox de envíos adicionales
    Me.txtEnviosAdicionales.Value = Null

End Sub


