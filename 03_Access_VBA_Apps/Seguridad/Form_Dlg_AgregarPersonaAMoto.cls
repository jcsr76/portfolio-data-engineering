VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Dlg_AgregarPersonaAMoto"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

Private p_id_vehiculo_pasado As Long

'=========================
' FORM LOAD
'=========================
Private Sub Form_Load()
    Dim vArg As Variant

    ' Recibir id_vehiculo del formulario principal
    vArg = Me.OpenArgs

    If IsNull(vArg) Or vArg = "" Then
        MsgBox "Error: no se recibió el identificador de la moto. Cierre este formulario e inténtelo nuevamente desde la gestión de motos.", _
               vbCritical, "Error de contexto"
        DoCmd.Close acForm, Me.Name
        Exit Sub
    End If

    p_id_vehiculo_pasado = CLng(vArg)

    ' Cargar combo de personas existentes (sin filtro aún, se filtra dinámicamente)
    CargarComboPersonasExistentes

    ' Limpiar campos
    LimpiarCampos
End Sub

'=========================
' CARGAR COMBO DE PERSONAS EXISTENTES
'=========================
Private Sub CargarComboPersonasExistentes()
    ' Mostrar personas que no estén ya en esta moto
    ' Por simplicidad, mostramos todas y validamos en VBA
    Me.cmbPersonaExistente.RowSource = _
        "SELECT id_persona, nombre, identificacion " & _
        "FROM vista_personas_sin_relacion_moto " & _
        "ORDER BY nombre;"
End Sub

'=========================
' LIMPIAR CAMPOS
'=========================
Private Sub LimpiarCampos()
    Me.cmbPersonaExistente = Null
    Me.txtNombreNuevo = Null
    Me.txtIdentificacionNuevo = Null
    Me.txtTelefonoNuevo = Null
    Me.txtDireccionNuevo = Null
    Me.cmbCiudadNuevo = Null
    Me.cmbRol = Null
End Sub

'=========================
' BOTÓN: AGREGAR
'=========================
Private Sub BTN_Agregar_Click()
    On Error GoTo ErrHandler

    Dim usuarioActual As String
    Dim sqlCall As String
    Dim sqlResultado As String
    Dim rs As ADODB.Recordset
    Dim resultado As Long
    Dim id_persona As Long
    Dim nombre As String
    Dim identificacion As String
    Dim telefono As String
    Dim direccion As String
    Dim ciudad As Long
    Dim rol As String
    Dim modoPersonaNueva As Boolean

    '=========================
    ' 0) Determinar modo
    '=========================
    modoPersonaNueva = (IsNull(Me.cmbPersonaExistente) Or Me.cmbPersonaExistente = "")

    '=========================
    ' 1) Validar según el modo
    '=========================
    If modoPersonaNueva Then
        ' Persona nueva
        If Trim(Nz(Me.txtNombreNuevo, "")) = "" Then
            MsgBox "Debe ingresar el nombre de la nueva persona.", vbExclamation, "Validación"
            Exit Sub
        End If

        If Trim(Nz(Me.txtIdentificacionNuevo, "")) = "" Then
            MsgBox "Debe ingresar la identificación de la nueva persona.", vbExclamation, "Validación"
            Exit Sub
        End If

        nombre = Nz(Me.txtNombreNuevo, "")
        identificacion = Nz(Me.txtIdentificacionNuevo, "")
        telefono = Nz(Me.txtTelefonoNuevo, "")
        direccion = Nz(Me.txtDireccionNuevo, "")
        ciudad = Nz(Me.cmbCiudadNuevo, 0)

    Else
        ' Persona existente
        If IsNull(Me.cmbPersonaExistente) Or Me.cmbPersonaExistente = "" Then
            MsgBox "Debe seleccionar una persona existente.", vbExclamation, "Validación"
            Exit Sub
        End If
        id_persona = Nz(Me.cmbPersonaExistente, 0)
    End If

    ' Rol obligatorio
    If IsNull(Me.cmbRol) Or Me.cmbRol = "" Then
        MsgBox "Debe seleccionar un rol.", vbExclamation, "Validación"
        Exit Sub
    End If
    rol = Me.cmbRol

    '=========================
    ' 2) Usuario y conexión
    '=========================
    usuarioActual = EstablecerUsuarioActual()
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual.", vbCritical, "Error"
        Exit Sub
    End If

    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con

    '=========================
    ' 3) MODO A: Persona existente -> SP sp_crear_relacion_persona_moto
    '=========================
    If Not modoPersonaNueva Then

        cnn.Execute "SET @p_resultado := 0;"

        sqlCall = "CALL sp_crear_relacion_persona_moto(" & _
                  p_id_vehiculo_pasado & ", " & _
                  id_persona & ", " & _
                  "'" & Replace(rol, "'", "''") & "', " & _
                  "'" & Replace(usuarioActual, "'", "''") & "', " & _
                  "@p_resultado" & _
                  ");"

        cnn.Execute sqlCall

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

        Select Case resultado
            Case 1
                MsgBox "La persona seleccionada quedó asociada a la moto con el rol indicado.", _
                       vbInformation, "Relación creada"
                Me.Tag = "GUARDADO"
                DoCmd.Close acForm, Me.Name

            Case -2
                MsgBox "Esa persona ya está asociada a esta moto con ese rol.", _
                       vbExclamation, "Relación duplicada"

            Case -1
                MsgBox "Ocurrió un error al crear la relación.", vbCritical, "Error"

            Case Else
                MsgBox "Resultado inesperado (" & resultado & ").", vbExclamation, "Aviso"
        End Select

        Exit Sub
    End If

    '=========================
    ' 4) MODO B: Persona nueva -> SP sp_agregar_persona_a_moto
    '=========================
    cnn.Execute "SET @p_resultado := 0;"

    sqlCall = "CALL sp_agregar_persona_a_moto(" & _
              p_id_vehiculo_pasado & ", " & _
              "NULL, " & _
              "'" & Replace(nombre, "'", "''") & "', " & _
              "'" & Replace(identificacion, "'", "''") & "', " & _
              "'" & Replace(telefono, "'", "''") & "', " & _
              "'" & Replace(direccion, "'", "''") & "', " & _
              ciudad & ", " & _
              "'" & Replace(rol, "'", "''") & "', " & _
              "'" & Replace(usuarioActual, "'", "''") & "', " & _
              "@p_resultado" & _
              ");"

    cnn.Execute sqlCall

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

    Select Case resultado
        Case 1
            MsgBox "La nueva persona se creó y se asoció a la moto correctamente.", _
                   vbInformation, "Éxito"
            Me.Tag = "GUARDADO"
            DoCmd.Close acForm, Me.Name

        Case -2
            MsgBox "La relación entre esa persona, esa moto y ese rol ya existe.", _
                   vbExclamation, "Relación duplicada"

        Case -1
            MsgBox "Ocurrió un error al crear la persona o la relación.", _
                   vbCritical, "Error"

        Case Else
            MsgBox "Resultado inesperado (" & resultado & ").", _
                   vbExclamation, "Aviso"
    End Select

    Exit Sub

ErrHandler:
    MsgBox "Error en BTN_Agregar_Click: " & Err.Description, vbCritical, "Error"
End Sub

'=========================
' BOTÓN: CANCELAR
'=========================
Private Sub BTN_Cancelar_Click()
    Me.Tag = "CANCELADO"
    DoCmd.Close acForm, Me.Name
End Sub

'=========================
' MAYÚSCULAS
'=========================
Private Sub txtNombreNuevo_Exit(Cancel As Integer)
    If Not IsNull(Me.txtNombreNuevo) Then
        Me.txtNombreNuevo = UCase(Me.txtNombreNuevo)
    End If
End Sub

Private Sub txtDireccionNuevo_Exit(Cancel As Integer)
    If Not IsNull(Me.txtDireccionNuevo) Then
        Me.txtDireccionNuevo = UCase(Me.txtDireccionNuevo)
    End If
End Sub


