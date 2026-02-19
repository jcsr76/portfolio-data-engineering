VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Gestion_motos_Terceros"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

Private Const SQL_MOTOS As String = _
    "SELECT id_vehiculo, placa, tipo, marca, modelo, anio, id_base, capacidad, estado, fecha_vencimiento_soat, ans " & _
    "FROM vista_motos_distinct"

Private Const SQL_PERSONAS As String = _
    "SELECT id_persona, nombre, identificacion, telefono1, direccion, ciudad, estado, id_vehiculo, placa, roles " & _
    "FROM vista_personas_motos"

'=========================
' LIMPIEZA DE CAMPOS
'=========================
Private Sub LimpiarCamposMoto()
    Me.txtid_vehiculo = Null
    Me.txtPlaca = Null
    Me.cmbTipo = Null
    Me.txtMarca = Null
    Me.txtModelo = Null
    Me.txtAnio = Null
    Me.cmbBase = Null
    Me.txtCapacidad = Null
    Me.cmbEstadoVehiculo = Null
    Me.dtFechaSoat = Null
    Me.chkANS = Null
    Me.lstPersonasEnMoto.RowSource = ""
    Me.lstPersonasEnMoto.Requery
End Sub

Private Sub LimpiarCamposPersona()
    Me.txtid_persona = Null
    Me.txtNombrePersona = Null
    Me.txtIdentificacion = Null
    Me.txtTelefonoPersona = Null
    Me.txtDireccionPersona = Null
    Me.cmbCiudadPersona = Null
    Me.cmbEstadoPersona = Null
End Sub

'=========================
' CARGAR LISTBOX MOTOS
'=========================
Private Sub CargarListboxMotos()
    Dim sql As String
    sql = SQL_MOTOS & " ORDER BY placa;"
    Me.lstMotos.RowSource = sql
    Me.lstMotos.Requery
End Sub

'=========================
' CARGAR LISTBOX PERSONAS
'=========================
Private Sub CargarListboxPersonas()
    Dim sql As String
    sql = SQL_PERSONAS & " ORDER BY nombre;"
    Me.lstPersonas.RowSource = sql
    Me.lstPersonas.Requery
End Sub

'=========================
' CLICK EN LISTBOX MOTOS
'=========================
Private Sub lstMotos_Click()
    If Me.lstMotos.ListIndex = -1 Then Exit Sub
    
    ' Mapear columnas al control txtid_vehiculo (columna 0)
    Me.txtid_vehiculo = Me.lstMotos.Column(0)   ' id_vehiculo
    Me.txtPlaca = Me.lstMotos.Column(1)         ' placa
    Me.cmbTipo = Me.lstMotos.Column(2)          ' tipo
    Me.txtMarca = Me.lstMotos.Column(3)         ' marca
    Me.txtModelo = Me.lstMotos.Column(4)        ' modelo
    Me.txtAnio = Me.lstMotos.Column(5)          ' anio
    Me.cmbBase = Me.lstMotos.Column(6)          ' id_base
    Me.txtCapacidad = Me.lstMotos.Column(7)     ' capacidad
    Me.cmbEstadoVehiculo = Me.lstMotos.Column(8) ' estado
    Me.dtFechaSoat = Me.lstMotos.Column(9)      ' fecha_vencimiento_soat
    Me.chkANS = Me.lstMotos.Column(10)          ' ans
    
    ' Cargar sub-listbox de personas de esta moto
    CargarPersonasEnMoto
End Sub

Private Sub CargarPersonasEnMoto()
    Dim sql As String
    Dim id_vehiculo As Long

    If IsNull(Me.txtid_vehiculo) Then
        Me.lstPersonasEnMoto.RowSource = ""
        Me.lstPersonasEnMoto.Requery
        Exit Sub
    End If

    id_vehiculo = Me.txtid_vehiculo

    ' Traer personas relacionadas a esa moto desde la vista completa
    sql = "SELECT id_persona, nombre_persona, identificacion, rol_en_vehiculo, estado_persona " & _
      "FROM vista_motos_con_personas " & _
      "WHERE id_vehiculo = " & id_vehiculo & " " & _
      "ORDER BY rol_en_vehiculo, nombre_persona;"

    Me.lstPersonasEnMoto.RowSource = sql
    Me.lstPersonasEnMoto.Requery
End Sub

'=========================
' CLICK EN LISTBOX PERSONAS
'=========================
Private Sub lstPersonas_Click()
    If Me.lstPersonas.ListIndex = -1 Then Exit Sub
    
    ' Mapear columnas (según vista_personas_motos)
    Me.txtid_persona = Me.lstPersonas.Column(0)         ' id_persona
    Me.txtNombrePersona = Me.lstPersonas.Column(1)      ' nombre
    Me.txtIdentificacion = Me.lstPersonas.Column(2)     ' identificacion
    Me.txtTelefonoPersona = Me.lstPersonas.Column(3)    ' telefono1
    Me.txtDireccionPersona = Me.lstPersonas.Column(4)   ' direccion
    Me.cmbCiudadPersona = Me.lstPersonas.Column(5)      ' ciudad
    Me.cmbEstadoPersona = Me.lstPersonas.Column(6)      ' estado
End Sub

'=========================
' BOTÓN: GUARDAR MOTO
'=========================
Private Sub BTN_GuardarMoto_Click()
    On Error GoTo ErrHandler

    Dim usuarioActual As String
    Dim sqlCall As String
    Dim sqlResultado As String
    Dim rs As ADODB.Recordset
    Dim resultado As Long
    Dim fechaSoat As String

    ' Validar selección
    If IsNull(Me.txtid_vehiculo) Or Me.txtid_vehiculo = "" Then
        MsgBox "Debe seleccionar primero una moto en la lista.", vbExclamation, "Seleccione registro"
        Exit Sub
    End If

    ' Obtener usuario actual
    usuarioActual = EstablecerUsuarioActual()
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual.", vbCritical, "Error"
        Exit Sub
    End If

    ' Verificar/conectar MySQL
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con

    ' Preparar fecha
    If IsNull(Me.dtFechaSoat) Or Me.dtFechaSoat = "" Then
        fechaSoat = "NULL"
    Else
        fechaSoat = "'" & Format(Me.dtFechaSoat, "yyyy-mm-dd") & "'"
    End If

    ' Llamar SP
    cnn.Execute "SET @p_resultado := 0;"

    sqlCall = "CALL sp_actualizar_moto_tercero(" & _
              Me.txtid_vehiculo & ", " & _
              "'" & Replace(Nz(Me.txtPlaca, ""), "'", "''") & "', " & _
              "'" & Replace(Nz(Me.cmbTipo, ""), "'", "''") & "', " & _
              "'" & Replace(Nz(Me.txtMarca, ""), "'", "''") & "', " & _
              "'" & Replace(Nz(Me.txtModelo, ""), "'", "''") & "', " & _
              Nz(Me.txtAnio, 0) & ", " & _
              Nz(Me.cmbBase, 0) & ", " & _
              Nz(Me.txtCapacidad, 0) & ", " & _
              "'" & Replace(Nz(Me.cmbEstadoVehiculo, ""), "'", "''") & "', " & _
              fechaSoat & ", " & _
              Nz(Me.chkANS, 0) & ", " & _
              "'" & Replace(usuarioActual, "'", "''") & "', " & _
              "@p_resultado" & _
              ");"

    cnn.Execute sqlCall

    ' Leer resultado
    sqlResultado = "SELECT @p_resultado AS resultado;"
    Set rs = New ADODB.Recordset
    rs.Open sqlResultado, cnn, adOpenForwardOnly, adLockReadOnly

    If Not rs.EOF Then
        resultado = Nz(rs.Fields("resultado").Value, -1)
    Else
        resultado = -1
    End If

    rs.Close
    Set rs = Nothing

    ' Interpretar resultado
    Select Case resultado
        Case 1
            MsgBox "Moto actualizada correctamente.", vbInformation, "Éxito"
        Case 0
            MsgBox "No se detectaron cambios en la moto.", vbInformation, "Sin cambios"
        Case -1
            MsgBox "Ocurrió un error al actualizar la moto.", vbCritical, "Error"
        Case Else
            MsgBox "Resultado inesperado (" & resultado & ").", vbExclamation, "Aviso"
    End Select

    ' Refrescar
    CargarListboxMotos
    CargarPersonasEnMoto
    Exit Sub

ErrHandler:
    MsgBox "Error en BTN_GuardarMoto_Click: " & Err.Description, vbCritical, "Error"
End Sub

'=========================
' BOTÓN: GUARDAR PERSONA
'=========================
Private Sub BTN_GuardarPersona_Click()
    On Error GoTo ErrHandler

    Dim usuarioActual As String
    Dim sqlCall As String
    Dim sqlResultado As String
    Dim rs As ADODB.Recordset
    Dim resultado As Long

    ' Validar selección
    If IsNull(Me.txtid_persona) Or Me.txtid_persona = "" Then
        MsgBox "Debe seleccionar primero una persona en la lista.", vbExclamation, "Seleccione registro"
        Exit Sub
    End If

    ' Obtener usuario actual
    usuarioActual = EstablecerUsuarioActual()
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual.", vbCritical, "Error"
        Exit Sub
    End If

    ' Verificar/conectar MySQL
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con

    ' Llamar SP
    cnn.Execute "SET @p_resultado := 0;"

    sqlCall = "CALL sp_actualizar_persona_tercero(" & _
              Me.txtid_persona & ", " & _
              "'" & Replace(Nz(Me.txtNombrePersona, ""), "'", "''") & "', " & _
              "'" & Replace(Nz(Me.txtIdentificacion, ""), "'", "''") & "', " & _
              "'" & Replace(Nz(Me.txtTelefonoPersona, ""), "'", "''") & "', " & _
              "'" & Replace(Nz(Me.txtDireccionPersona, ""), "'", "''") & "', " & _
              Nz(Me.cmbCiudadPersona, 0) & ", " & _
              "'" & Replace(Nz(Me.cmbEstadoPersona, ""), "'", "''") & "', " & _
              "'" & Replace(usuarioActual, "'", "''") & "', " & _
              "@p_resultado" & _
              ");"

    cnn.Execute sqlCall

    ' Leer resultado
    sqlResultado = "SELECT @p_resultado AS resultado;"
    Set rs = New ADODB.Recordset
    rs.Open sqlResultado, cnn, adOpenForwardOnly, adLockReadOnly

    If Not rs.EOF Then
        resultado = Nz(rs.Fields("resultado").Value, -1)
    Else
        resultado = -1
    End If

    rs.Close
    Set rs = Nothing

    ' Interpretar resultado
    Select Case resultado
        Case 1
            MsgBox "Persona actualizada correctamente.", vbInformation, "Éxito"
        Case 0
            MsgBox "No se detectaron cambios en la persona.", vbInformation, "Sin cambios"
        Case -1
            MsgBox "Ocurrió un error al actualizar la persona.", vbCritical, "Error"
        Case Else
            MsgBox "Resultado inesperado (" & resultado & ").", vbExclamation, "Aviso"
    End Select

    ' Refrescar
    CargarListboxPersonas
    CargarPersonasEnMoto  ' ? Añadir esta línea para refrescar el sub-listbox
    Exit Sub


ErrHandler:
    MsgBox "Error en BTN_GuardarPersona_Click: " & Err.Description, vbCritical, "Error"
End Sub


'=========================
' BOTÓN: LIMPIAR PERSONA
'=========================
Private Sub BTN_LimpiarPersona_Click()
    LimpiarCamposPersona
    CargarListboxPersonas
    Me.cmbNombreFiltroBuscarPersona = Null
    Me.cmbNombreFiltroBuscarIdentificacion = Null
    Me.cmbNombreFiltroBuscarPlaca = Null
End Sub
'=========================
' BOTÓN: AGREGAR PERSONA A MOTO
'=========================
Private Sub BTN_AgregarPersona_Click()
    On Error GoTo ErrHandler
    
    ' Validar que haya moto seleccionada
    If IsNull(Me.txtid_vehiculo) Or Trim(Nz(Me.txtid_vehiculo, "")) = "" Then
        MsgBox "Debe seleccionar una moto en la lista antes de agregar una persona.", _
               vbExclamation, "Seleccione una moto"
        Exit Sub
    End If
    
    ' Abrir formulario de diálogo, pasando id_vehiculo como OpenArgs
    DoCmd.OpenForm "Dlg_AgregarPersonaAMoto", , , , , acDialog, Me.txtid_vehiculo
    
    ' Después de cerrar el diálogo, refrescar personas de la moto
    CargarPersonasEnMoto
    
    Exit Sub
ErrHandler:
    MsgBox "Error en BTN_AgregarPersona_Click: " & Err.Description, vbCritical, "Error"
End Sub

'=========================
' BOTÓN: ELIMINAR RELACIÓN
'=========================
Private Sub BTN_EliminarRelacion_Click()
    On Error GoTo ErrHandler

    Dim usuarioActual As String
    Dim sqlCall As String
    Dim sqlResultado As String
    Dim rs As ADODB.Recordset
    Dim resultado As Long
    Dim respuesta As VbMsgBoxResult

    '=========================
    ' 0) Validar que haya moto, persona y rol seleccionados
    '=========================
    If IsNull(Me.txtid_vehiculo) Or Me.txtid_vehiculo = "" Then
        MsgBox "Debe seleccionar primero una moto en la lista.", _
               vbExclamation, "Seleccione una moto"
        Exit Sub
    End If

    If IsNull(Me.txtid_personaSeleccionada) Or Me.txtid_personaSeleccionada = "" Then
        MsgBox "Debe seleccionar primero una persona asociada a la moto antes de eliminar la relación.", _
               vbExclamation, "Seleccione una persona"
        Exit Sub
    End If

    If IsNull(Me.txtRol_personaSeleccionada) Or Me.txtRol_personaSeleccionada = "" Then
        MsgBox "Debe seleccionar un registro que incluya el rol de la persona en la moto.", _
               vbExclamation, "Seleccione un rol"
        Exit Sub
    End If

    '=========================
    ' 1) Confirmar con el usuario
    '=========================
    respuesta = MsgBox( _
        "Está a punto de eliminar la relación entre la persona seleccionada y esta moto." & vbCrLf & vbCrLf & _
        "Moto (ID): " & Nz(Me.txtid_vehiculo, "") & vbCrLf & _
        "Persona (ID): " & Nz(Me.txtid_personaSeleccionada, "") & vbCrLf & _
        "Rol en el vehículo: " & Nz(Me.txtRol_personaSeleccionada, "") & vbCrLf & vbCrLf & _
        "¿Desea continuar?", _
        vbQuestion + vbYesNo, "Confirmar eliminación de relación")

    If respuesta <> vbYes Then
        Exit Sub
    End If

    '=========================
    ' 2) Obtener usuario actual
    '=========================
    usuarioActual = EstablecerUsuarioActual()
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. La relación no se eliminará.", vbCritical, "Error"
        Exit Sub
    End If

    '=========================
    ' 3) Verificar/conectar MySQL
    '=========================
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con

    '=========================
    ' 4) Inicializar variable de salida y llamar al SP
    '=========================
    cnn.Execute "SET @p_resultado := 0;"

    sqlCall = "CALL sp_eliminar_relacion_persona_moto(" & _
              Nz(Me.txtid_vehiculo, 0) & ", " & _
              Nz(Me.txtid_personaSeleccionada, 0) & ", " & _
              "'" & Replace(Nz(Me.txtRol_personaSeleccionada, ""), "'", "''") & "', " & _
              "'" & Replace(usuarioActual, "'", "''") & "', " & _
              "@p_resultado" & _
              ");"

    cnn.Execute sqlCall

    '=========================
    ' 5) Leer @p_resultado
    '=========================
    sqlResultado = "SELECT @p_resultado AS resultado;"
    Set rs = New ADODB.Recordset
    rs.Open sqlResultado, cnn, adOpenForwardOnly, adLockReadOnly

    If Not rs.EOF Then
        resultado = Nz(rs.Fields("resultado").Value, -1)
    Else
        resultado = -1
    End If

    rs.Close
    Set rs = Nothing

    '=========================
    ' 6) Interpretar resultado
    '=========================
    Select Case resultado
        Case 1
            MsgBox "La relación entre la persona y la moto se eliminó correctamente.", _
                   vbInformation, "Relación eliminada"
        Case 0
            MsgBox "No se encontró la relación especificada. No se realizaron cambios.", _
                   vbInformation, "Sin cambios"
        Case -1
            MsgBox "Ocurrió un error al intentar eliminar la relación.", _
                   vbCritical, "Error"
        Case Else
            MsgBox "Resultado inesperado del procedimiento (" & resultado & ").", _
                   vbExclamation, "Aviso"
    End Select

    '=========================
    ' 7) Refrescar sub-listbox y limpiar selección
    '=========================
    CargarPersonasEnMoto
    Me.txtid_personaSeleccionada = Null
    Me.txtRol_personaSeleccionada = Null

    Exit Sub

ErrHandler:
    MsgBox "Error en BTN_EliminarRelacion_Click: " & Err.Description, vbCritical, "Error"
End Sub

'=========================
' FORM LOAD
'=========================
Private Sub Form_Load()
    LimpiarCamposMoto
    LimpiarCamposPersona
    CargarListboxMotos
    CargarListboxPersonas

    'Dejar vacío al iniciar
    Me.lstPersonasEnMoto.RowSource = ""
    Me.lstPersonasEnMoto.Requery
End Sub


Private Sub BTN_LimpiarMoto_Click()

    LimpiarCamposMoto
    LimpiarCamposPersona
    CargarListboxMotos
    CargarListboxPersonas

End Sub

Private Sub lstPersonasEnMoto_Click()
    If Me.lstPersonasEnMoto.ListIndex = -1 Then Exit Sub

    ' Columna 0: id_persona
    Me.txtid_personaSeleccionada = Me.lstPersonasEnMoto.Column(0)

    ' Columna 3: rol_en_vehiculo
    Me.txtRol_personaSeleccionada = Me.lstPersonasEnMoto.Column(3)
End Sub

'=========================
' MAYÚSCULAS EN TEXTBOX
'=========================
Private Sub txtPlaca_Exit(Cancel As Integer)
    If Not IsNull(Me.txtPlaca) Then
        Me.txtPlaca = UCase(Me.txtPlaca)
    End If
End Sub

Private Sub txtMarca_Exit(Cancel As Integer)
    If Not IsNull(Me.txtMarca) Then
        Me.txtMarca = UCase(Me.txtMarca)
    End If
End Sub

Private Sub txtModelo_Exit(Cancel As Integer)
    If Not IsNull(Me.txtModelo) Then
        Me.txtModelo = UCase(Me.txtModelo)
    End If
End Sub

Private Sub txtNombrePersona_Exit(Cancel As Integer)
    If Not IsNull(Me.txtNombrePersona) Then
        Me.txtNombrePersona = UCase(Me.txtNombrePersona)
    End If
End Sub

Private Sub txtDireccionPersona_Exit(Cancel As Integer)
    If Not IsNull(Me.txtDireccionPersona) Then
        Me.txtDireccionPersona = UCase(Me.txtDireccionPersona)
    End If
End Sub

'=========================
' APLICAR FILTROS A lstPersonas
'=========================
Private Sub AplicarFiltrosPersonas()
    Dim sql As String
    Dim whereParts As Collection
    Dim filtro As String
    
    sql = SQL_PERSONAS   ' SELECT ... FROM vista_personas_motos
    Set whereParts = New Collection
    
    ' Filtro por id_persona (cmbNombreFiltroBuscarPersona)
    If Not IsNull(Me.cmbNombreFiltroBuscarPersona) And Me.cmbNombreFiltroBuscarPersona <> "" Then
        whereParts.Add "id_persona = " & Nz(Me.cmbNombreFiltroBuscarPersona, 0)
    End If
    
    ' Filtro por identificación (cmbNombreFiltroBuscarIdentificacion)
    If Not IsNull(Me.cmbNombreFiltroBuscarIdentificacion) And Me.cmbNombreFiltroBuscarIdentificacion <> "" Then
        whereParts.Add "id_persona = " & Nz(Me.cmbNombreFiltroBuscarIdentificacion, 0)
    End If
    
    ' Filtro por placa / id_vehiculo (cmbNombreFiltroBuscarPlaca)
    If Not IsNull(Me.cmbNombreFiltroBuscarPlaca) And Me.cmbNombreFiltroBuscarPlaca <> "" Then
        whereParts.Add "id_vehiculo = " & Nz(Me.cmbNombreFiltroBuscarPlaca, 0)
    End If
    
    ' Construir WHERE dinámico
    If whereParts.Count > 0 Then
        Dim i As Long
        filtro = " WHERE "
        For i = 1 To whereParts.Count
            If i > 1 Then filtro = filtro & " AND "
            filtro = filtro & whereParts(i)
        Next i
        sql = sql & filtro
    End If
    
    ' ORDER BY fijo
    sql = sql & " ORDER BY nombre;"
    
    Me.lstPersonas.RowSource = sql
    Me.lstPersonas.Requery
End Sub


Private Sub cmbNombreFiltroBuscarPersona_AfterUpdate()
    AplicarFiltrosPersonas
End Sub

Private Sub cmbNombreFiltroBuscarIdentificacion_AfterUpdate()
    AplicarFiltrosPersonas
End Sub

Private Sub cmbNombreFiltroBuscarPlaca_AfterUpdate()
    AplicarFiltrosPersonas
End Sub



