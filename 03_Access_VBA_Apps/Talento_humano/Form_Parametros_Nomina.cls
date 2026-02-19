VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Parametros_Nomina"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

' ============================================================
' EVENTO: Clic en BTN_ActualizarSalario
' ============================================================
Private Sub BTN_ActualizarSalario_Click()
    On Error GoTo ErrHandler
    
    Dim sql As String
    Dim usuarioActual As String
    Dim resultado As Integer
    Dim anioAnterior As Integer
    Dim anioActual As Integer
    Dim respuesta As VbMsgBoxResult
    
    ' Calcular años automáticamente
    anioActual = Year(Date)
    anioAnterior = anioActual - 1
    
    '------------------------------------------
    ' Confirmación del usuario
    '------------------------------------------
    respuesta = MsgBox("¿Está seguro de actualizar los salarios mínimos y auxilios de transporte?" & vbCrLf & vbCrLf & _
                       "Se actualizarán todos los contratos vigentes que tengan:" & vbCrLf & _
                       "- Salario mínimo " & anioAnterior & " al valor de " & anioActual & vbCrLf & _
                       "- Auxilio de transporte " & anioAnterior & " al valor de " & anioActual & vbCrLf & vbCrLf & _
                       "Esta operación no se puede deshacer.", vbQuestion + vbYesNo, "Confirmar actualización masiva")
    
    If respuesta = vbNo Then Exit Sub
    
    '------------------------------------------
    ' Verificar conexión MySQL
    '------------------------------------------
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con

    '------------------------------------------
    ' Obtener usuario actual
    '------------------------------------------
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. No es posible continuar.", vbCritical
        Exit Sub
    End If
    
    '------------------------------------------
    ' Construir y ejecutar el SP
    '------------------------------------------
    sql = "CALL sp_actualizar_salarios_minimos(" & _
          anioAnterior & "," & _
          anioActual & "," & _
          "'" & usuarioActual & "'," & _
          "@resultado);"
    
    cnn.Execute sql
    
    ' Obtener el resultado del SP
    Dim rs As ADODB.Recordset
    Set rs = cnn.Execute("SELECT @resultado AS resultado")
    resultado = rs.Fields("resultado").value
    rs.Close
    Set rs = Nothing
    
    '------------------------------------------
    ' Evaluar resultado
    '------------------------------------------
    Select Case resultado
        Case Is > 0
            MsgBox "Actualización completada exitosamente." & vbCrLf & vbCrLf & _
                   "Total de actualizaciones realizadas: " & resultado & vbCrLf & _
                   "(Incluye salarios base y auxilios de transporte)", _
                   vbInformation, "Actualización exitosa"
            
            ' Refrescar controles si es necesario
            Call RequeryAllDataControls(Me)
            
        Case 0
            MsgBox "No se encontraron contratos vigentes con salario mínimo o auxilio de transporte del año " & anioAnterior & "." & vbCrLf & vbCrLf & _
                   "No se realizaron cambios.", vbInformation, "Sin cambios"
            
        Case -2
            MsgBox "No se encontraron los parámetros necesarios en la tabla parametros_nomina:" & vbCrLf & vbCrLf & _
                   "- SALARIO_MINIMO_" & anioAnterior & vbCrLf & _
                   "- SALARIO_MINIMO_" & anioActual & vbCrLf & _
                   "- AUXILIO_TRANSPORTE_" & anioAnterior & vbCrLf & _
                   "- AUXILIO_TRANSPORTE_" & anioActual & vbCrLf & vbCrLf & _
                   "Por favor, registre estos parámetros antes de continuar.", _
                   vbExclamation, "Parámetros faltantes"
            
        Case -1
            MsgBox "Error en la transacción al actualizar los contratos." & vbCrLf & _
                   "No se realizaron cambios.", vbCritical, "Error de transacción"
            
        Case Else
            MsgBox "Resultado inesperado del procedimiento almacenado: " & resultado, vbExclamation, "Advertencia"
    End Select
    
    Exit Sub

'------------------------------------------
' Manejo de errores
'------------------------------------------
ErrHandler:
    MsgBox "Error al actualizar salarios: " & Err.Number & " - " & Err.Description, vbCritical, "Error"
End Sub

'------------------------------------------
' Limpiar Formulario
'------------------------------------------
Private Sub BTN_Borrar_Click()
    Limpiar_Formulario_Parametros
End Sub

' ============================================================
' EVENTO: Clic en Botón Guardar
' ============================================================
Private Sub BTN_Guardar_Click()
    On Error GoTo ErrHandler
    
    Dim ctrl As Control
    Dim camposFaltantes As String
    Dim nombreAmigable As String
    Dim sql As String
    Dim usuarioActual As String
    Dim resultado As Integer

    '------------------------------------------
    ' Validar campos obligatorios
    '------------------------------------------
    ' En BTN_Guardar_Click, cambiar:
    Dim listaControles As Variant
    listaControles = Array("cmbTipoParametro", "txtAnioVigencia", "txtValorParametro")


    Dim i As Integer
    For i = LBound(listaControles) To UBound(listaControles)
        On Error Resume Next
        Set ctrl = Me.Controls(listaControles(i))
        On Error GoTo ErrHandler

        If Not ctrl Is Nothing Then
            ' Nombre amigable (sin el prefijo)
            nombreAmigable = Replace(Replace(Replace(Replace(ctrl.Name, "txt", ""), "cmb", ""), "chk", ""), "_", " ")
            
            ' Verificar si está vacío
            If (ctrl.ControlType = acTextBox And Trim(ctrl.value & "") = "") Then
                camposFaltantes = camposFaltantes & vbCrLf & "- " & nombreAmigable
            End If
        End If
    Next i

    '------------------------------------------
    ' Mostrar mensaje si hay campos vacíos
    '------------------------------------------
    If Len(camposFaltantes) > 0 Then
        MsgBox "Debe diligenciar los siguientes campos antes de guardar:" & vbCrLf & camposFaltantes, vbExclamation, "Campos incompletos"
        Exit Sub
    End If
    
    '------------------------------------------
    ' Verificar conexión MySQL
    '------------------------------------------
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con

    '------------------------------------------
    ' Obtener usuario actual
    '------------------------------------------
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. No es posible continuar.", vbCritical
        Exit Sub
    End If
    
    '------------------------------------------
    ' Determinar si es INSERT o UPDATE
    '------------------------------------------
    If Trim(Nz(Me.txtIdParametro, "")) = "" Then
        '========================================
        ' MODO INSERT
        '========================================
        sql = "CALL sp_crear_parametro_nomina(" & _
              "'" & Replace(Me.txtNombreParametro, "'", "''") & "'," & _
              Replace(Me.txtValorParametro, ",", ".") & "," & _
              IIf(Trim(Nz(Me.txtObservaciones, "")) = "", "NULL", "'" & Replace(Me.txtObservaciones, "'", "''") & "'") & "," & _
              "'" & usuarioActual & "'," & _
              "@resultado);"
        
        '------------------------------------------
        ' Ejecutar inserción en MySQL
        '------------------------------------------
        cnn.Execute sql
        
        ' Obtener el resultado del SP
        Dim rs As ADODB.Recordset
        Set rs = cnn.Execute("SELECT @resultado AS resultado")
        resultado = rs.Fields("resultado").value
        rs.Close
        Set rs = Nothing
        
        '------------------------------------------
        ' Evaluar resultado de la inserción
        '------------------------------------------
        Select Case resultado
            Case 1
                MsgBox "Parámetro de nómina registrado correctamente.", vbInformation, "Registro exitoso"
                Call Limpiar_Formulario_Parametros
                Call RequeryAllDataControls(Me)
                
            Case -2
                MsgBox "El parámetro '" & Me.txtNombreParametro & "' ya existe en el sistema." & vbCrLf & _
                       "Use el modo de actualización si desea modificar su valor.", vbExclamation, "Parámetro duplicado"
                Me.txtNombreParametro.SetFocus
                
            Case -1
                MsgBox "Error en la transacción al registrar el parámetro.", vbCritical, "Error de transacción"
                
            Case Else
                MsgBox "Resultado inesperado del procedimiento almacenado: " & resultado, vbExclamation, "Advertencia"
        End Select
        
    Else
        '========================================
        ' MODO UPDATE
        '========================================
        sql = "CALL sp_actualizar_parametro_nomina(" & _
              Me.txtIdParametro & "," & _
              "'" & Replace(Me.txtNombreParametro, "'", "''") & "'," & _
              Replace(Me.txtValorParametro, ",", ".") & "," & _
              IIf(Trim(Nz(Me.txtObservaciones, "")) = "", "NULL", "'" & Replace(Me.txtObservaciones, "'", "''") & "'") & "," & _
              "'" & usuarioActual & "'," & _
              "@resultado);"
        
        '------------------------------------------
        ' Ejecutar actualización en MySQL
        '------------------------------------------
        cnn.Execute sql
        
        ' Obtener el resultado del SP
        Dim rsUpd As ADODB.Recordset
        Set rsUpd = cnn.Execute("SELECT @resultado AS resultado")
        resultado = rsUpd.Fields("resultado").value
        rsUpd.Close
        Set rsUpd = Nothing
        
        '------------------------------------------
        ' Evaluar resultado de la actualización
        '------------------------------------------
        Select Case resultado
            Case 1
                MsgBox "Parámetro de nómina actualizado correctamente.", vbInformation, "Actualización exitosa"
                Call Limpiar_Formulario_Parametros
                Call RequeryAllDataControls(Me)
                
            Case 0
                MsgBox "No se detectaron cambios en el parámetro seleccionado.", vbInformation, "Sin cambios"
                
            Case -1
                MsgBox "Error en la transacción al actualizar el parámetro.", vbCritical, "Error de transacción"
                
            Case Else
                MsgBox "Resultado inesperado del procedimiento almacenado: " & resultado, vbExclamation, "Advertencia"
        End Select
    End If
    
    Exit Sub

'------------------------------------------
' Manejo de errores
'------------------------------------------
ErrHandler:
    Dim errorMsg As String
    errorMsg = Err.Description
    
    ' Verificar si es un error de duplicado
    If InStr(errorMsg, "Duplicate entry") > 0 Or _
       InStr(errorMsg, "nombre_parametro") > 0 Or _
       InStr(errorMsg, "Unique") > 0 Or _
       Err.Number = -2147467259 Then
        
        MsgBox "El parámetro '" & Me.txtNombreParametro & "' ya está registrado en el sistema." & vbCrLf & _
               "Use el modo de actualización si desea modificar sus datos.", vbExclamation, "Parámetro duplicado"
        Me.txtNombreParametro.SetFocus
        
    Else
        MsgBox "Error al guardar parámetro: " & Err.Number & " - " & errorMsg, vbCritical, "Error"
    End If
End Sub

' ============================================================
' FUNCIÓN: Limpiar controles del formulario de parámetros
' ============================================================
Private Sub Limpiar_Formulario_Parametros()
    On Error Resume Next
    
    Me.txtIdParametro.value = Null
    Me.cmbTipoParametro.value = Null
    Me.txtAnioVigencia.value = Year(Date)  ' Restablecer año actual
    Me.txtNombreParametro.value = Null
    Me.txtValorParametro.value = Null
    Me.txtObservaciones.value = Null
    
    ' Establecer foco
    Me.cmbTipoParametro.SetFocus
    
    On Error GoTo 0
End Sub

' ============================================================
' EVENTO: AfterUpdate en txtNombreParametro
' ============================================================
Private Sub txtNombreParametro_AfterUpdate()
    On Error Resume Next
    If Not IsNull(Me.txtNombreParametro.value) Then
        Me.txtNombreParametro.value = UCase(Trim(Me.txtNombreParametro.value))
    End If
    On Error GoTo 0
End Sub

' ============================================================
' EVENTO: AfterUpdate en txtObservaciones
' ============================================================
Private Sub txtObservaciones_AfterUpdate()
    On Error Resume Next
    If Not IsNull(Me.txtObservaciones.value) Then
        Me.txtObservaciones.value = UCase(Trim(Me.txtObservaciones.value))
    End If
    On Error GoTo 0
End Sub

' ============================================================
' EVENTO: Click en lstParametrosNomina
' ============================================================
Private Sub lstParametrosNomina_Click()
    On Error GoTo ErrHandler
    
    Dim nombreCompleto As String
    Dim partes() As String
    
    ' Verificar que hay un registro seleccionado
    If IsNull(Me.lstParametrosNomina.value) Then Exit Sub
    
    ' Cargar datos del registro
    Me.txtIdParametro.value = Me.lstParametrosNomina.Column(0)
    nombreCompleto = Nz(Me.lstParametrosNomina.Column(1), "")
    Me.txtValorParametro.value = Nz(Me.lstParametrosNomina.Column(2), "")
    Me.txtObservaciones.value = Nz(Me.lstParametrosNomina.Column(3), "")
    
    ' Descomponer nombre: SALARIO_MINIMO_2026 -> SALARIO_MINIMO + 2026
    If nombreCompleto <> "" Then
        partes = Split(nombreCompleto, "_")
        If UBound(partes) >= 2 Then
            ' Extraer año (última parte)
            Me.txtAnioVigencia.value = partes(UBound(partes))
            
            ' Extraer tipo (todo menos el año)
            ReDim Preserve partes(UBound(partes) - 1)
            Me.cmbTipoParametro.value = Join(partes, "_")
        End If
    End If
    
    ' Generar nombre completo
    Me.txtNombreParametro.value = nombreCompleto
    
    Exit Sub

ErrHandler:
    MsgBox "Error al cargar el parámetro: " & Err.Number & " - " & Err.Description, vbCritical, "Error"
End Sub


' ============================================================
' EVENTO: Form_Load - Cargar lista de tipos de parámetros
' ============================================================
Private Sub Form_Load()
    ' Cargar lista cerrada de tipos de parámetros
    Me.cmbTipoParametro.RowSourceType = "Value List"
    Me.cmbTipoParametro.RowSource = "SALARIO_MINIMO;AUXILIO_TRANSPORTE"
    
    ' Establecer año actual por defecto
    Me.txtAnioVigencia.value = Year(Date)
End Sub

' ============================================================
' EVENTO: AfterUpdate en txtAnioVigencia - Validar año
' ============================================================
Private Sub txtAnioVigencia_AfterUpdate()
    On Error Resume Next
    
    Dim anioIngresado As Integer
    Dim anioActual As Integer
    
    ' Validar que sea numérico de 4 dígitos
    If Not IsNumeric(Me.txtAnioVigencia.value) Or Len(Me.txtAnioVigencia.value) <> 4 Then
        MsgBox "El año debe ser un número de 4 dígitos (Ejemplo: 2026)", vbExclamation, "Año inválido"
        Me.txtAnioVigencia.value = Null
        Me.txtAnioVigencia.SetFocus
        Exit Sub
    End If
    
    anioIngresado = CInt(Me.txtAnioVigencia.value)
    anioActual = Year(Date)
    
    ' Validar que sea año actual o siguiente
    If anioIngresado < anioActual Or anioIngresado > (anioActual + 1) Then
        MsgBox "El año debe ser el año actual (" & anioActual & ") o el siguiente (" & (anioActual + 1) & ")", _
               vbExclamation, "Año fuera de rango"
        Me.txtAnioVigencia.value = Null
        Me.txtAnioVigencia.SetFocus
        Exit Sub
    End If
    
    ' Generar nombre del parámetro automáticamente
    Call GenerarNombreParametro
    
    On Error GoTo 0
End Sub

' ============================================================
' EVENTO: AfterUpdate en cmbTipoParametro
' ============================================================
Private Sub cmbTipoParametro_AfterUpdate()
    ' Generar nombre del parámetro cuando cambia el tipo
    Call GenerarNombreParametro
End Sub

' ============================================================
' FUNCIÓN: Generar nombre del parámetro concatenando tipo + año
' ============================================================
Private Sub GenerarNombreParametro()
    On Error Resume Next
    
    ' Verificar que ambos campos tengan valor
    If Not IsNull(Me.cmbTipoParametro.value) And Not IsNull(Me.txtAnioVigencia.value) Then
        ' Concatenar: SALARIO_MINIMO_2026
        Me.txtNombreParametro.value = Me.cmbTipoParametro.value & "_" & Me.txtAnioVigencia.value
    Else
        Me.txtNombreParametro.value = Null
    End If
    
    On Error GoTo 0
End Sub

