VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Candados_Satelitales"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

Private Sub ActualizarCandadosPorOpcion()
    Dim opcion As Variant
    opcion = Me.Marco58

    Dim habilitarGrupo1 As Boolean
    Dim habilitarGrupo2 As Boolean
    Dim habilitarGrupo3 As Boolean

    ' Validar que la opción no esté vacía
    If IsNull(opcion) Then
        habilitarGrupo1 = False
        habilitarGrupo2 = False
        habilitarGrupo3 = False
    Else
        habilitarGrupo1 = (opcion = 1)
        habilitarGrupo2 = (opcion = 2)
        habilitarGrupo3 = (opcion = 3)
    End If

    ' --- Grupo 1: Ingreso Candados Operación ---
    If Not habilitarGrupo1 Then
        Me.txtNumeroCandado = Null
        Me.txtMarcaCandado = Null
        Me.txtModeloCandado = Null
    End If
    Me.txtNumeroCandado.Enabled = habilitarGrupo1
    Me.txtMarcaCandado.Enabled = habilitarGrupo1
    Me.txtModeloCandado.Enabled = habilitarGrupo1
    Me.btnBorrarIngreso.Enabled = habilitarGrupo1
    Me.btnRegistrarCandado.Enabled = habilitarGrupo1

    ' --- Grupo 2: Actualizar Estatus Candados ---
    If Not habilitarGrupo2 Then
        Me.cmbNumeroCandadoActualizar = Null
        Me.cmbEstatusCandadoActualizar = Null
    End If
    Me.cmbNumeroCandadoActualizar.Enabled = habilitarGrupo2
    Me.cmbEstatusCandadoActualizar.Enabled = habilitarGrupo2
    Me.btnBorrarEstatusCandado.Enabled = habilitarGrupo2
    Me.btnActualizarEstatus.Enabled = habilitarGrupo2

    ' --- Grupo 3: Movimiento Candados ---
    If Not habilitarGrupo3 Then
        Me.cmbNumeroCandadoOperacion = Null
        Me.txtUbicacion = Null
        Me.txtPlaca = Null
        Me.cmbEstatusOperativo = Null
        Me.txtObservaciones = Null
    End If
    Me.cmbNumeroCandadoOperacion.Enabled = habilitarGrupo3
    Me.txtUbicacion.Enabled = habilitarGrupo3
    Me.txtPlaca.Enabled = habilitarGrupo3
    Me.cmbEstatusOperativo.Enabled = habilitarGrupo3
    Me.txtObservaciones.Enabled = habilitarGrupo3
    Me.btnBorrarMovimientoCandados.Enabled = habilitarGrupo3
    Me.btnGuardarMovimiento.Enabled = habilitarGrupo3
End Sub

Private Sub LimpiarGrupo1_CandadoNuevo()
    On Error GoTo ErrHandler

    Me.txtNumeroCandado = Null
    Me.txtMarcaCandado = Null
    Me.txtModeloCandado = Null

    Exit Sub

ErrHandler:
    MsgBox "Error al limpiar Grupo 1: " & Err.Description, vbExclamation, "Error"
End Sub

Private Sub LimpiarGrupo2_ActualizarEstado()
    On Error GoTo ErrHandler

    Me.cmbNumeroCandadoActualizar = Null
    Me.cmbEstatusCandadoActualizar = Null

    Exit Sub

ErrHandler:
    MsgBox "Error al limpiar Grupo 2: " & Err.Description, vbExclamation, "Error"
End Sub

Private Sub LimpiarGrupo3_Operacion()
    On Error GoTo ErrHandler

    Me.cmbNumeroCandadoOperacion = Null
    Me.txtUbicacion = Null
    Me.txtPlaca = Null
    Me.cmbEstatusOperativo = Null
    Me.txtObservaciones = Null

    Exit Sub

ErrHandler:
    MsgBox "Error al limpiar Grupo 3: " & Err.Description, vbExclamation, "Error"
End Sub


Private Sub btnActualizarEstatus_Click()
    On Error GoTo ErrHandler

    Dim sql As String
    Dim candadoID As Variant
    Dim estatus As String
    Dim usuarioActual As String

    '------------------------------------------
    ' Validaciones obligatorias
    '------------------------------------------
    If IsNull(Me.cmbNumeroCandadoActualizar) Or Trim(Me.cmbNumeroCandadoActualizar & "") = "" Then
        MsgBox "Debe seleccionar un candado.", vbExclamation, "Validación"
        Exit Sub
    End If

    If IsNull(Me.cmbEstatusCandadoActualizar) Or Trim(Me.cmbEstatusCandadoActualizar & "") = "" Then
        MsgBox "Debe seleccionar un estatus.", vbExclamation, "Validación"
        Exit Sub
    End If

    ' Mapeo: combo -> candado_id (normalmente el Value ya es el BoundColumn = candado_id)
    candadoID = Me.cmbNumeroCandadoActualizar.Value

    ' Mapeo: combo -> estatus (texto exacto del ENUM)
    estatus = CStr(Me.cmbEstatusCandadoActualizar.Value)

    ' Usuario actual (si lo estás exigiendo como en otros botones)
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. La operación no se puede completar.", vbCritical
        Exit Sub
    End If

    '------------------------------------------
    ' Verificar y reconectar MySQL
    '------------------------------------------
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con

    '------------------------------------------
    ' Ejecutar SP (escape de comillas por seguridad)
    '------------------------------------------
    sql = "CALL sp_actualizar_estatus_candado_satelital(" & _
          candadoID & ",'" & Replace(estatus, "'", "''") & "');"

    cnn.Execute sql

    '------------------------------------------
    ' Éxito + limpieza de controles involucrados
    '------------------------------------------
    MsgBox "Estatus actualizado correctamente.", vbInformation, "Actualización exitosa"
    Call LimpiarGrupo2_ActualizarEstado
    Exit Sub

ErrHandler:
    Dim errorMsg As String
    errorMsg = Err.Description

    ' Si el SP responde con SIGNAL SQLSTATE '45000', el texto viaja en el error devuelto al cliente. [web:14]
    MsgBox "Error al actualizar estatus: " & Err.Number & " - " & errorMsg, vbCritical, "Error"
End Sub


Private Sub btnBorrarEstatusCandado_Click()
    'Limpiar Sección Actualizar Estatus Candados
    Call LimpiarGrupo2_ActualizarEstado
End Sub

Private Sub btnBorrarIngreso_Click()
    'Limpiar Sección Ingreso Candados Operación
    Call LimpiarGrupo1_CandadoNuevo
End Sub

Private Sub btnBorrarMovimientoCandados_Click()
    'Limpiar Sección Movimientos Candados
    Call LimpiarGrupo3_Operacion
End Sub

Private Sub btnGuardarMovimiento_Click()
    On Error GoTo ErrHandler

    Dim sql As String
    Dim candadoID As Variant
    Dim fechaMov As Variant
    Dim ubicacion As String
    Dim placa As String
    Dim estatusOperativo As String
    Dim observaciones As String
    Dim usuarioActual As String

    '------------------------------------------
    ' Validaciones obligatorias
    '------------------------------------------
    If IsNull(Me.cmbNumeroCandadoOperacion) Or Trim(Me.cmbNumeroCandadoOperacion & "") = "" Then
        MsgBox "Debe seleccionar un candado.", vbExclamation, "Validación"
        Exit Sub
    End If

    If IsNull(Me.txtFechaMovimiento) Or Trim(Me.txtFechaMovimiento & "") = "" Then
        MsgBox "Debe ingresar la fecha del movimiento.", vbExclamation, "Validación"
        Exit Sub
    End If

    If Not IsDate(Me.txtFechaMovimiento.Value) Then
        MsgBox "La fecha del movimiento no es válida.", vbExclamation, "Validación"
        Exit Sub
    End If

    If IsNull(Me.cmbEstatusOperativo) Or Trim(Me.cmbEstatusOperativo & "") = "" Then
        MsgBox "Debe seleccionar el estatus operativo.", vbExclamation, "Validación"
        Exit Sub
    End If

    '------------------------------------------
    ' Mapear valores (según tu mapeo)
    '------------------------------------------
    candadoID = Me.cmbNumeroCandadoOperacion.Value                ' candado_id (int)
    fechaMov = Me.txtFechaMovimiento.Value                        ' fecha (date)
    ubicacion = Trim(Nz(Me.txtUbicacion.Value, ""))               ' ubicacion (varchar 150)
    placa = Trim(Nz(Me.txtPlaca.Value, ""))                       ' placa_asignada (varchar 6)
    estatusOperativo = CStr(Me.cmbEstatusOperativo.Value)         ' enum(...)
    observaciones = Trim(Nz(Me.txtObservaciones.Value, ""))       ' text

    '------------------------------------------
    ' Validaciones de longitud (evitar errores del lado MySQL)
    '------------------------------------------
    If Len(ubicacion) > 150 Then
        MsgBox "La ubicación no puede exceder 150 caracteres.", vbExclamation, "Validación"
        Exit Sub
    End If

    If Len(placa) > 6 Then
        MsgBox "La placa no puede exceder 6 caracteres.", vbExclamation, "Validación"
        Exit Sub
    End If

    ' Usuario actual (misma práctica que vienes usando)
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. La operación no se puede completar.", vbCritical
        Exit Sub
    End If

    '------------------------------------------
    ' Verificar y reconectar MySQL
    '------------------------------------------
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con

    '------------------------------------------
    ' Construir y ejecutar el CALL
    ' Nota: fecha en formato ISO 'YYYY-MM-DD' para evitar problemas regionales
    '------------------------------------------
    sql = "CALL sp_insertar_movimiento_candado(" & _
          candadoID & "," & _
          "'" & Format(CDate(fechaMov), "yyyy-mm-dd") & "'," & _
          "'" & Replace(ubicacion, "'", "''") & "'," & _
          "'" & Replace(placa, "'", "''") & "'," & _
          "'" & Replace(estatusOperativo, "'", "''") & "'," & _
          "'" & Replace(observaciones, "'", "''") & "'" & _
          ");"

    cnn.Execute sql

    '------------------------------------------
    ' Éxito + limpieza de controles involucrados
    '------------------------------------------
    MsgBox "Movimiento registrado correctamente.", vbInformation, "Registro exitoso"
    Call LimpiarGrupo3_Operacion
    Exit Sub

ErrHandler:
    Dim errorMsg As String
    errorMsg = Err.Description

    ' Tu SP devuelve errores controlados con SIGNAL SQLSTATE '45000' (mensaje legible para el usuario). [web:14]
    MsgBox "Error al registrar movimiento: " & Err.Number & " - " & errorMsg, vbCritical, "Error"
End Sub


Private Sub btnRegistrarCandado_Click()
    On Error GoTo ErrHandler

    Dim ctrl As Control
    Dim camposFaltantes As String
    Dim nombreAmigable As String
    Dim sql As String
    Dim usuarioActual As String

    Dim listaControles As Variant
    Dim i As Integer

    Dim numeroCandado As String
    Dim marca As String
    Dim modelo As String

    '------------------------------------------
    ' Función local para escapar comillas simples (estilo tu ejemplo Replace(...,"'","''"))
    '------------------------------------------
    Dim EscSQL As Object  ' late-bound "lambda" no existe en VBA; se usa inline con Replace/Nz

    '------------------------------------------
    ' Validar campos obligatorios
    '------------------------------------------
    listaControles = Array("txtNumeroCandado", "txtMarcaCandado", "txtModeloCandado")

    For i = LBound(listaControles) To UBound(listaControles)
        On Error Resume Next
        Set ctrl = Me.Controls(listaControles(i))
        On Error GoTo ErrHandler

        If Not ctrl Is Nothing Then
            nombreAmigable = Replace(Replace(Replace(Replace(ctrl.Name, "txt", ""), "cmb", ""), "chk", ""), "_", " ")

            If (ctrl.ControlType = acTextBox And Trim(ctrl.Value & "") = "") Then
                camposFaltantes = camposFaltantes & vbCrLf & "- " & nombreAmigable
            End If
        End If
    Next i

    If Len(camposFaltantes) > 0 Then
        MsgBox "Debe diligenciar los siguientes campos:" & vbCrLf & camposFaltantes, vbExclamation, "Campos incompletos"
        Exit Sub
    End If

    '------------------------------------------
    ' Normalizar/validar longitudes (numero_candado es VARCHAR(5))
    '------------------------------------------
    numeroCandado = Trim(Nz(Me.txtNumeroCandado.Value, ""))
    marca = Trim(Nz(Me.txtMarcaCandado.Value, ""))
    modelo = Trim(Nz(Me.txtModeloCandado.Value, ""))

    If Len(numeroCandado) = 0 Then
        MsgBox "Debe ingresar el número de candado.", vbExclamation, "Validación"
        Exit Sub
    End If

    If Len(numeroCandado) > 20 Then
    MsgBox "El número de candado no puede exceder 20 caracteres.", vbExclamation, "Validación"
    Exit Sub
    End If


    If Len(marca) > 50 Then
        MsgBox "La marca no puede exceder 50 caracteres.", vbExclamation, "Validación"
        Exit Sub
    End If

    If Len(modelo) > 50 Then
        MsgBox "El modelo no puede exceder 50 caracteres.", vbExclamation, "Validación"
        Exit Sub
    End If

    '------------------------------------------
    ' Verificar conexión MySQL
    '------------------------------------------
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con

    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual.", vbCritical
        Exit Sub
    End If

    '------------------------------------------
    ' Construir y ejecutar el CALL (MISMO PATRÓN que tu ejemplo: Replace para comillas)
    '------------------------------------------
    sql = "CALL sp_insertar_candado_satelital(" & _
          "'" & Replace(numeroCandado, "'", "''") & "'," & _
          "'" & Replace(marca, "'", "''") & "'," & _
          "'" & Replace(modelo, "'", "''") & "');"

    cnn.Execute sql  ' Execute ejecuta el statement en el servidor [web:48]

    '------------------------------------------
    ' Éxito
    '------------------------------------------
    MsgBox "Candado registrado correctamente.", vbInformation, "Registro exitoso"
    Call LimpiarFormularioIngresoCandados
    Exit Sub

ErrHandler:
    Dim errorMsg As String
    errorMsg = Err.Description

    ' Si tu SP usa SIGNAL SQLSTATE '45000' con MESSAGE_TEXT, ese texto viaja al cliente [web:14]
    If InStr(1, errorMsg, "Número de candado ya registrado", vbTextCompare) > 0 Then
        MsgBox "El número de candado '" & numeroCandado & "' ya está registrado.", vbExclamation, "Registro duplicado"
    ElseIf InStr(1, errorMsg, "Duplicate entry", vbTextCompare) > 0 Or InStr(1, errorMsg, "numero_candado", vbTextCompare) > 0 Then
        MsgBox "El número de candado '" & numeroCandado & "' ya está registrado.", vbExclamation, "Registro duplicado"
    Else
        MsgBox "Error al registrar candado: " & Err.Number & " - " & errorMsg, vbCritical, "Error"
    End If
End Sub

' Configuracion Carga de Formulario
Private Sub Form_Load()
    ' Al cargar, dejar selector sin opción y deshabilitar/limpiar todos los controles
    Me.Marco58 = Null
    Call ActualizarCandadosPorOpcion
End Sub

'Actualizar según selección de la opción
Private Sub Marco58_AfterUpdate()
    Call ActualizarCandadosPorOpcion
End Sub

'---------------------------------------------------------------------------------------
' FUNCIÓN: LimpiarFormularioIngresoCandados
' PROPÓSITO: Limpiar exclusivamente los controles del módulo de candados satelitales
'---------------------------------------------------------------------------------------
Public Function LimpiarFormularioIngresoCandados()
    On Error Resume Next
    
    ' Limpiar los cuadros de texto mapeados para candados
    Me.txtNumeroCandado = Null
    Me.txtMarcaCandado = Null
    Me.txtModeloCandado = Null
    
    ' Posicionar el cursor en el primer campo del módulo
    Me.txtNumeroCandado.SetFocus
    
    ' Refrescar el formulario para asegurar que los cambios sean visibles
    Me.Repaint
    
    On Error GoTo 0
End Function

