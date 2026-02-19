VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Cierre_Operacion"
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
    strSQL = _
      "SELECT O.operacion_id, O.fecha, BD.bases, O.vehiculo, O.placa, O.sector, SD.contrato, O.nombre_ruta " & _
      "FROM (vista_operaciones AS O INNER JOIN vista_bases_deprisa AS BD ON O.estacion = BD.base_id) " & _
      "INNER JOIN vista_sectores_deprisa AS SD ON O.sector = SD.sector " & _
      "WHERE " & baseWhere & " " & _
      "ORDER BY O.fecha DESC;"

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
    Me.chkCierreDiaSiguiente.Enabled = False
End Sub

'----------------------------
' Botón "Guardar": llama al stored procedure para cerrar el despacho
'----------------------------
Private Sub BTN_Guardar_Click()
    On Error GoTo ErrHandler

    Dim operacionID           As Variant
    Dim kmFinal               As Double
    Dim horaFinal             As Date
    Dim cantidadDevoluciones  As Integer
    Dim cantidadRecolecciones As Integer
    Dim cantidadNoRecogidos   As Integer
    Dim horasNoOperativas     As Double
    Dim strHorasNoOp          As String  ' Variable auxiliar
    Dim sql                   As String
    Dim rsSesion As DAO.Recordset
    Dim usuarioActual As String
    Dim recolecciones As Long
    Dim noEfectivas As Long
    Dim cierreSiguiente As Integer
    
    ' Obtener el usuario actual usando la función global
    usuarioActual = EstablecerUsuarioActual

    ' Verificar si no se pudo obtener el usuario
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. El registro no se puede completar.", vbCritical
        Exit Sub
    End If
    
    ' Validaciones previas
    If IsNull(Me.txtKmFinal) Or Me.txtKmFinal = "" Then
        MsgBox "El campo 'Kilometraje Final' es obligatorio.", vbExclamation
        Exit Sub
    End If
    
    ' ==============================
    ' VALIDACIÓN: kmFinal > kmInicial
    ' ==============================
    kmInicial = Nz(Me.txtKmInicial, 0)
    kmFinal = Nz(Me.txtKmFinal, 0)
    
    ' Verificar si kmFinal es menor que kmInicial
    If (kmFinal < kmInicial) Or (kmFinal = kmInicial And kmFinal <> 0) Then
        MsgBox "El 'Kilometraje Final' debe ser mayor que el 'Kilometraje Inicial', excepto cuando ambos son 0. y es un servicio de Back Office", vbExclamation
        Me.txtKmFinal.Value = ""  ' Borrar el valor de txtKmFinal
        Exit Sub
    End If

    
    If IsNull(Me.cmbHorafinal) Or Me.cmbHorafinal = "" Then
        MsgBox "La 'Hora Final' es obligatoria.", vbExclamation
        Me.ActiveControl.SetFocus       ' Cambiar a 'txtKmFinal' con una validación previa
        Me.cmbHorafinal.SetFocus       ' Establece el fofo en cmbHorafinal
        Exit Sub
    End If
    
    If IsNull(Me.txtDevoluciones) Or Me.txtDevoluciones = "" Then
        MsgBox "El campo 'Devoluciones' es obligatorio.", vbExclamation
        Exit Sub
    End If
    
    If IsNull(Me.txtRecolecciones) Or Me.txtRecolecciones = "" Then
        MsgBox "El campo 'Recolecciones' es obligatorio.", vbExclamation
        Exit Sub
    End If
    
    If IsNull(Me.txtRecoleccionesNoEfectivas) Or Me.txtRecoleccionesNoEfectivas = "" Then
        MsgBox "El campo 'Recolecciones No Efectivas' es obligatorio.", vbExclamation
        Exit Sub
    End If
    
    ' Validar que las recolecciones no efectivas no sean mayores que las recolecciones totales
    recolecciones = Nz(Me.txtRecolecciones.Value, 0)
    noEfectivas = Nz(Me.txtRecoleccionesNoEfectivas.Value, 0)

    If noEfectivas > recolecciones Then
        MsgBox "El número de recolecciones no efectivas no puede ser mayor que el número total de recolecciones.", vbExclamation
        Me.txtRecoleccionesNoEfectivas.SetFocus
        Exit Sub
    End If

    ' Asegurarse de que el operacion_id esté seleccionado en el ListBox
    operacionID = Me.lstOperaciones.Column(0)
    If IsNull(operacionID) Or operacionID = "" Then
        MsgBox "Debe seleccionar una operación.", vbExclamation
        Exit Sub
    End If

    ' Obtener valores de los controles
    kmFinal = Nz(Me.txtKmFinal, 0)
    horaFinal = Nz(Me.cmbHorafinal, 0)
    cantidadDevoluciones = Nz(Me.txtDevoluciones, 0)
    cantidadRecolecciones = Nz(Me.txtRecolecciones, 0)
    cantidadNoRecogidos = Nz(Me.txtRecoleccionesNoEfectivas, 0)
    horasNoOperativas = Nz(Me.txtHorasNoOperativas, 0)
    cierreSiguiente = IIf(Me.chkCierreDiaSiguiente.Value, 1, 0)

    ' Convertir "horasNoOperativas" a cadena con punto como separador decimal
    strHorasNoOp = Replace(CStr(horasNoOperativas), ",", ".")
    
    ' Montar la llamada al stored procedure (usando strHorasNoOp)
    sql = "CALL completar_operacion(" & _
          operacionID & ", " & _
          kmFinal & ", '" & _
          Format(horaFinal, "HH:mm:ss") & "', " & _
          cantidadDevoluciones & ", " & _
          cantidadRecolecciones & ", " & _
          cantidadNoRecogidos & ", " & _
          strHorasNoOp & ", '" & usuarioActual & "', " & _
          cierreSiguiente & ");"

    ' Verificar y reconectar si es necesario
    If Not VerificarYReconectarMySQL() Then Exit Sub


    ' Ejecutar el procedimiento almacenado
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con
    cnn.Execute sql

    ' Limpiar y poner fecha actual
    Call LimpiarCampos
    Me.txtFecha.Value = Date
    Call FiltrarListBoxOperaciones
    
    ' Deshabilitar los campos que usa el usuario
    Me.txtKmFinal.Enabled = False
    Me.cmbHorafinal.Enabled = False
    Me.txtDevoluciones.Enabled = False
    Me.txtRecolecciones.Enabled = False
    Me.txtRecoleccionesNoEfectivas.Enabled = False
    Me.chkCierreDiaSiguiente.Enabled = False

    MsgBox "Operación actualizada correctamente.", vbInformation
    
    ' Forzar la actualizacion de todas las consultas de los controles del formulario
    Call RequeryAllDataControls(Me)
    
    Exit Sub

ErrHandler:
    MsgBox "Error: " & Err.Number & " - " & Err.Description
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
        Me.cmbHorafinal = Null       ' Limpiar la hora final al cambiar selección
        Me.txtHorasNoOperativas = "" ' Limpiar horas no operativas
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

    ' No llamamos a ActualizarHorasNoOperativas aquí para evitar validaciones prematuras
    ' Solo dejamos limpio el cmbHorafinal y txtHorasNoOperativas
    Me.cmbHorafinal = Null
    Me.txtHorasNoOperativas = ""
    
    ' ==========================
    ' HABILITAR LOS CAMPOS
    ' ==========================
    Me.txtKmFinal.Enabled = True
    Me.cmbHorafinal.Enabled = True
    Me.txtDevoluciones.Enabled = True
    Me.txtRecolecciones.Enabled = True
    Me.txtRecoleccionesNoEfectivas.Enabled = True
    Me.chkCierreDiaSiguiente.Enabled = True
    
End Sub

'----------------------------
' Calcular y actualizar horas no operativas (usado únicamente al actualizar cmbHorafinal)
'----------------------------
Private Sub ActualizarHorasNoOperativas()
    Dim horaIni          As Date
    Dim horaFin          As Date
    Dim horasReales      As Double
    Dim horasNoOperativas As Double

    ' Validar valor y tipo de txtHoraInicio
    If IsNull(Me.txtHoraInicio) Or Not IsDate(Me.txtHoraInicio) Then
        MsgBox "Hora Inicio inválida o vacía", vbExclamation
        Me.txtHorasNoOperativas = 0
        Exit Sub
    Else
        horaIni = CDate(Me.txtHoraInicio)
    End If
    
    ' Validar que cmbHorafinal no esté vacío y sea fecha válida
    If IsNull(Me.cmbHorafinal) Or Not IsDate(Me.cmbHorafinal) Then
        MsgBox "Hora Final inválida o vacía", vbExclamation
        Me.txtHorasNoOperativas = 0
        Exit Sub
    Else
        horaFin = CDate(Me.cmbHorafinal)
    End If
    
    ' Calcular horas reales y luego horas no operativas
    horasReales = CalcularHorasReales(horaIni, horaFin)
    horasNoOperativas = CalcularHorasNoOperativas(horasReales)
    
    ' Asignar al textbox con redondeo a dos decimales
    Me.txtHorasNoOperativas = Round(horasNoOperativas, 2)
End Sub

'----------------------------
' Evento para cuando se actualice la hora final
'----------------------------
Private Sub cmbHoraFinal_AfterUpdate()
    On Error GoTo ErrHandler
    Dim horaInicio As Date
    Dim horaFinal As Date
    Dim horaInicioStr As String
    Dim horaFinalStr As String

    ' Verificar si txtHoraInicio tiene un valor válido
    If IsNull(Me.txtHoraInicio.Value) Or Me.txtHoraInicio.Value = "" Then
        ' No hacer nada si no hay hora de inicio todavía
        Exit Sub
    End If
    
    ' Salir si la hora final está vacía
    If IsNull(Me.cmbHorafinal.Value) Then Exit Sub

    ' Obtener el valor de hora de inicio (txtHoraInicio) y hora final (cmbHoraFinal)
    horaInicioStr = Format(Me.txtHoraInicio.Value, "HH:mm:ss")
    horaFinalStr = Format(Me.cmbHorafinal.Value, "HH:mm:ss")
    
    horaInicio = CDate(horaInicioStr)
    horaFinal = CDate(horaFinalStr)

    ' --- LÓGICA AJUSTADA ---
    ' Si la hora final es anterior a la de inicio Y la casilla NO está marcada...
    If horaFinal < horaInicio And Me.chkCierreDiaSiguiente.Value = False Then
        ' ...entonces es un error.
        MsgBox "La hora final es anterior a la de inicio. Si el cierre es al día siguiente, por favor marque la casilla correspondiente.", vbCritical
        Me.cmbHorafinal.Value = Null ' Limpia el valor inválido
    Else
        ' Si la hora es posterior O si es anterior PERO la casilla está marcada, es válido.
        Call ActualizarHorasNoOperativas
    End If
    
    Exit Sub
ErrHandler:
    MsgBox "Error: " & Err.Description, vbCritical
End Sub

' Asegurarse que la cantidad de devoluciones no sea superior a la cantidad de envíos
Private Sub txtDevoluciones_AfterUpdate()
    Dim devoluciones As Long
    Dim envios As Long

    devoluciones = Nz(Me.txtDevoluciones.Value, 0)
    envios = Nz(Me.txtEnvios.Value, 0)

    If devoluciones > envios Then
        MsgBox "El número de devoluciones no puede ser mayor que el número de envíos.", vbExclamation
        Me.txtDevoluciones.Value = Null
        Me.txtDevoluciones.SetFocus
    End If
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

    ' Deshabilitar los campos al cargar el formulario
    Me.txtKmFinal.Enabled = False
    Me.cmbHorafinal.Enabled = False
    Me.txtDevoluciones.Enabled = False
    Me.txtRecolecciones.Enabled = False
    Me.txtRecoleccionesNoEfectivas.Enabled = False
    Me.chkCierreDiaSiguiente.Enabled = False
End Sub

'----------------------------
' Función para Limpiar Formulario
'----------------------------
Private Sub LimpiarCampos()
    ' Limpiar ComboBoxes
    
    Me.cmbPlacaVehiculo.Value = ""
    Me.cmbHorafinal.Value = ""
    
    ' Limpiar ListBoxes
    Me.lstOperaciones.RowSource = ""
    Me.lstOT.RowSource = ""
    
    ' Resetar selector de día siguiente
    Me.chkCierreDiaSiguiente.Value = False
    
    ' Limpiar TextBoxes
    Me.txtVehiculo = ""
    Me.txtPlaca = ""
    Me.txtHoraInicio = ""
    Me.txtKmInicial = ""
    Me.txtEnvios = ""
    Me.txtHorasNoOperativas = ""
    Me.txtKmFinal = ""
    Me.txtDevoluciones = ""
    Me.txtRecolecciones = ""
    Me.txtRecoleccionesNoEfectivas = ""
    
    ' No sobrescribir txtFecha aquí para no perder el filtro actual
End Sub
