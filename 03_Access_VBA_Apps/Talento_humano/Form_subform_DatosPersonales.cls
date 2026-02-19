VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_subform_DatosPersonales"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

' ====================================================================
' CÓDIGO DENTRO DEL SUBFORMULARIO: subform_DatosPersonales
' ====================================================================

' Evento que se dispara DESPUÉS de que el usuario selecciona un país.
Private Sub cmbPaisNacimiento_AfterUpdate()
    ' Limpiamos los combos dependientes para forzar una nueva selección.
    Me.cmbCiudadNacimiento = Null
    Me.cmbDepartamentoNacimiento = Null
    
    ' Si se ha seleccionado un país válido...
    If Not IsNull(Me.cmbPaisNacimiento) Then
        ' Construimos el nuevo RowSource para el combo de ciudades, filtrando
        ' por el NOMBRE del país seleccionado (Columna 1 del combo de países).
        ' Importante: incluimos las 4 columnas que necesitamos
        Me.cmbCiudadNacimiento.RowSource = "SELECT id_ciudad, ciudad, Departamento_Estado, departamento_id " & _
                                          "FROM vista_ciudades_departamentos " & _
                                          "WHERE Pais = '" & Me.cmbPaisNacimiento.Column(1) & "' " & _
                                          "ORDER BY ciudad;"
    Else
        ' Si se deselecciona el país, vaciamos la lista de ciudades.
        Me.cmbCiudadNacimiento.RowSource = ""
    End If
    
    ' Actualizamos el combo de ciudades.
    Me.cmbCiudadNacimiento.Requery
End Sub

' Evento que se dispara DESPUÉS de que el usuario selecciona una ciudad.
Private Sub cmbCiudadNacimiento_AfterUpdate()
    ' Limpiamos el departamento.
    Me.cmbDepartamentoNacimiento = Null
    
    ' Si se ha seleccionado una ciudad válida...
    If Not IsNull(Me.cmbCiudadNacimiento) Then
        ' Asignamos automáticamente el departamento. El ID del departamento
        ' es la cuarta columna (índice 3) de nuestro combo de ciudades.
        Me.cmbDepartamentoNacimiento = Me.cmbCiudadNacimiento.Column(3)
    End If
End Sub

' ====================================================================
' Eventos para convertir a MAYÚSCULAS en los TextBox
' ====================================================================

Private Sub txtPrimerNombre_AfterUpdate()
    Me.txtPrimerNombre = UCase(Me.txtPrimerNombre)
End Sub

Private Sub txtSegundoNombre_AfterUpdate()
    Me.txtSegundoNombre = UCase(Me.txtSegundoNombre)
End Sub

Private Sub txtPrimerApellido_AfterUpdate()
    Me.txtPrimerApellido = UCase(Me.txtPrimerApellido)
End Sub

Private Sub txtSegundoApellido_AfterUpdate()
    Me.txtSegundoApellido = UCase(Me.txtSegundoApellido)
End Sub

Private Sub txtDireccion_AfterUpdate()
    Me.txtDireccion = UCase(Me.txtDireccion)
End Sub

Private Sub txtBarrio_AfterUpdate()
    Me.txtBarrio = UCase(Me.txtBarrio)
End Sub

Private Sub txtPlanta_AfterUpdate()
    Me.txtPlanta = UCase(Me.txtPlanta)
End Sub

Private Sub txtContactoEmergencia_AfterUpdate()
    Me.txtContactoEmergencia = UCase(Me.txtContactoEmergencia)
End Sub

Private Sub txtTelefonoContactoEmergencia_AfterUpdate()
    Me.txtTelefonoContactoEmergencia = UCase(Me.txtTelefonoContactoEmergencia)
End Sub

'==================================================================================================
' EVENTO CLICK DEL BOTÓN "GUARDAR REGISTRO"
' Ubicación: DENTRO del subformulario subform_DatosPersonales
' SP: sp_actualizar_colaborador
'==================================================================================================
Private Sub BTN_Guardar_Click()
    On Error GoTo ErrHandler
    
    Dim cmd As ADODB.Command
    Dim usuarioActual As String

    '--- 1. VALIDACIÓN DE CAMPOS OBLIGATORIOS ---
    If Nz(Me.txtid_colaborador, 0) = 0 Then
        MsgBox "Debe seleccionar un colaborador de la lista antes de continuar.", vbExclamation, "Faltan datos"
        Exit Sub
    End If

    If Trim(Nz(Me.txtPrimerNombre.value, "")) = "" Then
        MsgBox "El Primer Nombre es un campo obligatorio.", vbExclamation, "Dato Requerido"
        Me.txtPrimerNombre.SetFocus
        Exit Sub
    End If

    If Trim(Nz(Me.txtPrimerApellido.value, "")) = "" Then
        MsgBox "El Primer Apellido es un campo obligatorio.", vbExclamation, "Dato Requerido"
        Me.txtPrimerApellido.SetFocus
        Exit Sub
    End If

    If Trim(Nz(Me.txtNumID.value, "")) = "" Then
        MsgBox "El Número de Identificación es un campo obligatorio.", vbExclamation, "Dato Requerido"
        Me.txtNumID.SetFocus
        Exit Sub
    End If

    '--- 2. CONEXIÓN A MYSQL Y OBTENCIÓN DE USUARIO ---
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con

    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. No es posible continuar.", vbCritical
        Exit Sub
    End If

   '--- 3. CONFIGURAR Y EJECUTAR EL PROCEDIMIENTO ALMACENADO ---
   
    Dim vFechaExp As Variant
    Dim vFechaNac As Variant
    Dim vFechaEMO As Variant
    Dim vFechaProxEMO As Variant
    Dim vFechaCarnet As Variant

    ' Fecha Expedición
    If Nz(Me.txtFechaExpedicion.value, "") = "" Then
        vFechaExp = Null
    ElseIf IsDate(Me.txtFechaExpedicion.value) Then
        vFechaExp = Format$(CDate(Me.txtFechaExpedicion.value), "yyyy-mm-dd")
    Else
        MsgBox "La fecha de expedición no es válida.", vbExclamation, "Fecha incorrecta"
        Me.txtFechaExpedicion.SetFocus
        Exit Sub
    End If
    
    ' Fecha Nacimiento
    If Nz(Me.txtFechaNacimiento.value, "") = "" Then
        vFechaNac = Null
    ElseIf IsDate(Me.txtFechaNacimiento.value) Then
        vFechaNac = Format$(CDate(Me.txtFechaNacimiento.value), "yyyy-mm-dd")
    Else
        MsgBox "La fecha de nacimiento no es válida.", vbExclamation, "Fecha incorrecta"
        Me.txtFechaNacimiento.SetFocus
        Exit Sub
    End If
    
    ' Fecha EMO
    If Nz(Me.txtFechaEMO.value, "") = "" Then
        vFechaEMO = Null
    ElseIf IsDate(Me.txtFechaEMO.value) Then
        vFechaEMO = Format$(CDate(Me.txtFechaEMO.value), "yyyy-mm-dd")
    Else
        MsgBox "La fecha EMO no es válida.", vbExclamation, "Fecha incorrecta"
        Me.txtFechaEMO.SetFocus
        Exit Sub
    End If
    
    ' Fecha Próximo EMO
    If Nz(Me.txtFechaProxEMO.value, "") = "" Then
        vFechaProxEMO = Null
    ElseIf IsDate(Me.txtFechaProxEMO.value) Then
        vFechaProxEMO = Format$(CDate(Me.txtFechaProxEMO.value), "yyyy-mm-dd")
    Else
        MsgBox "La fecha Próximo EMO no es válida.", vbExclamation, "Fecha incorrecta"
        Me.txtFechaProxEMO.SetFocus
        Exit Sub
    End If
    
    ' Fecha Elaboración Carnet
    If Nz(Me.txtFechaCarnet.value, "") = "" Then
        vFechaCarnet = Null
    ElseIf IsDate(Me.txtFechaCarnet.value) Then
        vFechaCarnet = Format$(CDate(Me.txtFechaCarnet.value), "yyyy-mm-dd")
    Else
        MsgBox "La fecha de elaboración del carnet no es válida.", vbExclamation, "Fecha incorrecta"
        Me.txtFechaCarnet.SetFocus
        Exit Sub
    End If

   
   
Set cmd = New ADODB.Command
With cmd
    .ActiveConnection = cnn
    .CommandType = adCmdStoredProc
    .CommandText = "sp_actualizar_colaborador"
    
    .Parameters.Append .CreateParameter("p_id_colaborador", adInteger, adParamInput, , Nz(Me.txtid_colaborador.value, 0))
    .Parameters.Append .CreateParameter("p_tipo_id", adVarChar, adParamInput, 5, Nz(Me.cmbTipoID.value, ""))
    .Parameters.Append .CreateParameter("p_id_cc", adVarChar, adParamInput, 20, Trim(Nz(Me.txtNumID.value, "")))
    .Parameters.Append .CreateParameter("p_lugar_expedicion", adInteger, adParamInput, , Nz(Me.cmbLugarExpedicion.value, Null))

    ' Fechas como texto ISO yyyy-mm-dd (o Null si está vacío)
    .Parameters.Append .CreateParameter("p_fecha_expedicion", adVarChar, adParamInput, 10, vFechaExp)
    
    .Parameters.Append .CreateParameter("p_primer_nombre", adVarChar, adParamInput, 100, Trim(Nz(Me.txtPrimerNombre.value, "")))
    .Parameters.Append .CreateParameter("p_segundo_nombre", adVarChar, adParamInput, 100, Trim(Nz(Me.txtSegundoNombre.value, "")))
    .Parameters.Append .CreateParameter("p_primer_apellido", adVarChar, adParamInput, 100, Trim(Nz(Me.txtPrimerApellido.value, "")))
    .Parameters.Append .CreateParameter("p_segundo_apellido", adVarChar, adParamInput, 100, Trim(Nz(Me.txtSegundoApellido.value, "")))
    .Parameters.Append .CreateParameter("p_formacion_academica", adVarChar, adParamInput, 50, Nz(Me.cmbFormacionAcademica.value, ""))
    .Parameters.Append .CreateParameter("p_estado_formacion_academica", adVarChar, adParamInput, 50, Nz(Me.cmbEstadoFormacionAcademica.value, ""))

    .Parameters.Append .CreateParameter("p_fecha_nacimiento", adVarChar, adParamInput, 10, vFechaNac)

    .Parameters.Append .CreateParameter("p_sexo", adVarChar, adParamInput, 10, Nz(Me.cmbSexo.value, ""))
    .Parameters.Append .CreateParameter("p_grupo_sanguineo", adVarChar, adParamInput, 5, Nz(Me.cmbGrupoSanguineo.value, ""))
    .Parameters.Append .CreateParameter("p_rh", adVarChar, adParamInput, 3, Nz(Me.cmbRH.value, ""))
    .Parameters.Append .CreateParameter("p_estado_civil", adVarChar, adParamInput, 50, Nz(Me.cmbEstadoCivil.value, ""))
    .Parameters.Append .CreateParameter("p_direccion", adVarChar, adParamInput, 255, Trim(Nz(Me.txtDireccion.value, "")))
    .Parameters.Append .CreateParameter("p_barrio", adVarChar, adParamInput, 200, Trim(Nz(Me.txtBarrio.value, "")))
    .Parameters.Append .CreateParameter("p_estrato", adVarChar, adParamInput, 10, Nz(Me.cmbEstrato.value, ""))
    .Parameters.Append .CreateParameter("p_ciudad_nacimiento", adInteger, adParamInput, , Nz(Me.cmbCiudadNacimiento.value, Null))
    .Parameters.Append .CreateParameter("p_departamento_nacimiento", adInteger, adParamInput, , Nz(Me.cmbDepartamentoNacimiento.value, Null))
    .Parameters.Append .CreateParameter("p_pais_nacimiento", adInteger, adParamInput, , Nz(Me.cmbPaisNacimiento.value, Null))
    .Parameters.Append .CreateParameter("p_estatus_colaborador", adVarChar, adParamInput, 50, Nz(Me.cmbEstatusColaborador.value, ""))
    .Parameters.Append .CreateParameter("p_departamento", adInteger, adParamInput, , Nz(Me.cmbDepartamento.value, Null))
    .Parameters.Append .CreateParameter("p_cargo", adInteger, adParamInput, , Nz(Me.cmbCargo.value, Null))
    .Parameters.Append .CreateParameter("p_sede", adInteger, adParamInput, , Nz(Me.cmbSede.value, Null))
    .Parameters.Append .CreateParameter("p_planta", adVarChar, adParamInput, 20, Trim(Nz(Me.txtPlanta.value, "")))
    .Parameters.Append .CreateParameter("p_id_jefe", adInteger, adParamInput, , Nz(Me.cmbJefeInmediato.value, Null))

    .Parameters.Append .CreateParameter("p_fecha_emo", adVarChar, adParamInput, 10, vFechaEMO)

    .Parameters.Append .CreateParameter("p_fecha_proximo_emo", adVarChar, adParamInput, 10, vFechaProxEMO)

    .Parameters.Append .CreateParameter("p_fecha_elaboracion_carnet", adVarChar, adParamInput, 10, vFechaCarnet)

    ' Checkbox: normalizar a 1/0
    Dim vRuta As Integer
    vRuta = IIf(Me.chkRutaInduccion.value = True, 1, 0)
    .Parameters.Append .CreateParameter("p_ruta_induccion", adTinyInt, adParamInput, , vRuta)

    .Parameters.Append .CreateParameter("p_contacto_emergencia", adVarChar, adParamInput, 150, Trim(Nz(Me.txtContactoEmergencia.value, "")))
    .Parameters.Append .CreateParameter("p_telefono_contacto_emergencia", adVarChar, adParamInput, 150, Trim(Nz(Me.txtTelefonoContactoEmergencia.value, "")))
    .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)

    .Execute

End With


    ' Si llegamos aquí, la actualización fue exitosa (sin errores del SP)
    MsgBox "Los datos del colaborador se han actualizado correctamente.", vbInformation, "Actualización Exitosa"
    Call CalcularEdadActual
    Call LimpiarFormulario

ExitSub:
    On Error Resume Next
    Set cmd = Nothing
    Exit Sub

ErrHandler:
    Dim descripcion As String
    
    descripcion = Nz(Err.Description, "")
    
    ' Búsquedas en ORDEN de especificidad (MÁS ESPECÍFICO PRIMERO)
    If InStr(descripcion, "No se detectaron cambios") > 0 Then
        MsgBox "No se detectaron cambios en los datos del colaborador.", vbInformation, "Sin cambios"
    ElseIf InStr(descripcion, "no existe en el sistema") > 0 Then
        MsgBox "El colaborador especificado no existe en el sistema.", vbCritical, "Error de Datos"
    ElseIf InStr(descripcion, "Error inesperado") > 0 Then
        MsgBox "Ocurrió un error inesperado. Por favor contacte al administrador.", vbCritical, "Error del Sistema"
    Else
        MsgBox "Error: " & descripcion, vbCritical, "Error de Actualización"
    End If
    
    Resume ExitSub

End Sub

' Limpieza del Formulario
Private Sub LimpiarFormulario()
    Me.txtid_colaborador = ""
    Me.cmbTipoID = Null
    Me.txtNumID = ""
    Me.cmbLugarExpedicion = Null
    Me.txtFechaExpedicion = ""
    Me.txtPrimerNombre = ""
    Me.txtSegundoNombre = ""
    Me.txtPrimerApellido = ""
    Me.txtSegundoApellido = ""
    Me.cmbFormacionAcademica = Null
    Me.cmbEstadoFormacionAcademica = Null
    Me.txtFechaNacimiento = ""
    Me.cmbSexo = Null
    Me.cmbGrupoSanguineo = Null
    Me.cmbRH = Null
    Me.cmbEstadoCivil = Null
    Me.txtDireccion = ""
    Me.txtBarrio = ""
    Me.cmbEstrato = Null
    Me.cmbCiudadNacimiento = Null
    Me.cmbDepartamentoNacimiento = Null
    Me.cmbPaisNacimiento = Null
    Me.cmbEstatusColaborador = Null
    Me.cmbDepartamento = Null
    Me.cmbCargo = Null
    Me.cmbSede = Null
    Me.txtPlanta = ""
    Me.cmbJefeInmediato = Null
    Me.txtFechaEMO = ""
    Me.txtFechaProxEMO = ""
    Me.txtFechaCarnet = ""
    Me.chkRutaInduccion = False
    Me.txtContactoEmergencia = ""
    Me.txtTelefonoContactoEmergencia = ""
    Me.txtEdadActual = ""
    Me.txtRol = ""
End Sub


'==================================================================================================
' PROCEDIMIENTO PÚBLICO: CargarDatos
' Función: Carga los datos del colaborador desde MySQL basado en idColaboradorActual
' Parámetro: id_colaborador (Long) - ID del colaborador a cargar
'==================================================================================================
Public Sub CargarDatos(id_colaborador As Long)
    Dim rsColaborador As Object
    Dim rsPais As Object
    Dim sql As String
    Dim nombrePais As String

    If id_colaborador <= 0 Then Exit Sub

    Set rsColaborador = CreateObject("ADODB.Recordset")
    Set rsPais = CreateObject("ADODB.Recordset")
    
    sql = "SELECT * FROM vista_colaboradores WHERE id_colaborador = " & id_colaborador
    
    On Error GoTo CargarDatos_Error

    rsColaborador.Open sql, CurrentProject.Connection, 1

    If Not rsColaborador.EOF Then
        ' PASO 1: BUSCAR EL NOMBRE DEL PAÍS
        If Not IsNull(rsColaborador!pais_nacimiento) Then
            sql = "SELECT nombre FROM vista_paises WHERE pais_id = " & rsColaborador!pais_nacimiento
            rsPais.Open sql, CurrentProject.Connection, 1
            If Not rsPais.EOF Then
                nombrePais = rsPais!nombre
            End If
            rsPais.Close
        End If

        ' LÓGICA DE CARGA EN CASCADA
        ' A. PAÍS
        Me.cmbPaisNacimiento = Nz(rsColaborador!pais_nacimiento)
        
        ' B. CIUDAD
        Me.cmbCiudadNacimiento.RowSource = "SELECT id_ciudad, ciudad, Departamento_Estado, departamento_id " & _
                                          "FROM vista_ciudades_departamentos " & _
                                          "WHERE Pais = '" & nombrePais & "' " & _
                                          "ORDER BY ciudad;"
        Me.cmbCiudadNacimiento.Requery
        Me.cmbCiudadNacimiento = Nz(rsColaborador!ciudad_nacimiento)
        
        ' C. DEPARTAMENTO
        Me.cmbDepartamentoNacimiento = Nz(rsColaborador!departamento_nacimiento)

        ' El resto de los campos
        Me.txtid_colaborador = Nz(rsColaborador!id_colaborador, 0)
        Me.cmbTipoID = Nz(rsColaborador!tipo_id)
        Me.txtNumID = Nz(rsColaborador!id_cc, "")
        Me.cmbLugarExpedicion = Nz(rsColaborador!lugar_expedicion)
        Me.txtFechaExpedicion = Nz(rsColaborador!fecha_expedicion)
        Me.txtPrimerNombre = Nz(rsColaborador!primer_nombre, "")
        Me.txtSegundoNombre = Nz(rsColaborador!segundo_nombre, "")
        Me.txtPrimerApellido = Nz(rsColaborador!primer_apellido, "")
        Me.txtSegundoApellido = Nz(rsColaborador!segundo_apellido, "")
        Me.cmbFormacionAcademica = Nz(rsColaborador!formacion_academica)
        Me.cmbEstadoFormacionAcademica = Nz(rsColaborador!estado_formacion_academica)
        Me.txtFechaNacimiento = Nz(rsColaborador!fecha_nacimiento)
        Me.cmbSexo = Nz(rsColaborador!sexo)
        Me.cmbGrupoSanguineo = Nz(rsColaborador!grupo_sanguineo)
        Me.cmbRH = Nz(rsColaborador!rh)
        Me.cmbEstadoCivil = Nz(rsColaborador!estado_civil)
        Me.txtDireccion = Nz(rsColaborador!direccion, "")
        Me.txtBarrio = Nz(rsColaborador!barrio, "")
        Me.cmbEstrato = Nz(rsColaborador!estrato)
        Me.cmbEstatusColaborador = Nz(rsColaborador!estatus_colaborador)
        Me.cmbDepartamento = Nz(rsColaborador!departamento)
        Me.cmbCargo = Nz(rsColaborador!cargo)
        Call CargarRolDesdeCargo
        Me.cmbSede = Nz(rsColaborador!sede)
        Me.txtPlanta = Nz(rsColaborador!planta, "")
        Me.cmbJefeInmediato = Nz(rsColaborador!id_jefe)
        Me.txtFechaEMO = Nz(rsColaborador!fecha_emo)
        Me.txtFechaProxEMO = Nz(rsColaborador!fecha_proximo_emo)
        Me.txtFechaCarnet = Nz(rsColaborador!fecha_elaboracion_carnet)
        Me.chkRutaInduccion = (Nz(rsColaborador!ruta_induccion, 0) = 1)
        Me.txtContactoEmergencia = Nz(rsColaborador!contacto_emergencia, "")
        Me.txtTelefonoContactoEmergencia = Nz(rsColaborador!telefono_contacto_emergencia, "")
    End If
    
    ' Calcular edad actual a partir de la fecha de nacimiento
    Call CalcularEdadActual


CargarDatos_Limpieza:
    On Error Resume Next
    rsColaborador.Close
    rsPais.Close
    Set rsColaborador = Nothing
    Set rsPais = Nothing
    Exit Sub

CargarDatos_Error:
    MsgBox "Ocurrió un error al cargar los datos: " & Err.Description, vbCritical
    Resume CargarDatos_Limpieza
End Sub

'==================================================================================================
' EVENTO CLICK DEL BOTÓN "BORRAR" o "LIMPIAR"
' Ubicación: DENTRO del subformulario subform_DatosPersonales
'==================================================================================================
Private Sub BTN_Borrar_Click()
    ' Preguntar al usuario si está seguro, para evitar perder datos no guardados.
    If MsgBox("¿Estás seguro de que deseas limpiar todos los campos de este formulario? " & _
              "Cualquier cambio no guardado se perderá.", _
              vbQuestion + vbYesNo, "Confirmar Limpieza") = vbYes Then
              
        ' Llamar a la función de limpieza que ya existe.
        Call LimpiarFormulario
        
        ' Opcional: Mover el foco al primer campo editable para mejorar la experiencia.
        Me.cmbTipoID.SetFocus
        
    End If
End Sub

'==================================================================================================
' --- EVENTO: cmbCargo_AfterUpdate
' --- Función: Cuando el usuario selecciona un cargo en cmbCargo,
'            carga automáticamente el valor de "rol" en txtRol
'==================================================================================================

Private Sub cmbCargo_AfterUpdate()
    Call CargarRolDesdeCargo
End Sub

'==================================================================================================
' FUNCIÓN PRIVADA: CalcularEdadActual
' Función: Calcula la edad en años (entero) a partir de txtFechaNacimiento
'          y la muestra en txtEdadActual. No usa ninguna tabla ni SP.
'==================================================================================================
Private Sub CalcularEdadActual()
    Dim fNac As Date
    Dim edad As Long
    
    ' Si no hay fecha válida, limpiar el campo y salir
    If Not IsDate(Nz(Me.txtFechaNacimiento, "")) Then
        Me.txtEdadActual = Null
        Exit Sub
    End If
    
    fNac = CDate(Me.txtFechaNacimiento)
    
    ' Cálculo de edad en años completos
    edad = DateDiff("yyyy", fNac, Date)
    
    ' Ajustar si aún no ha cumplido años este año
    If Date < DateSerial(Year(Date), Month(fNac), Day(fNac)) Then
        edad = edad - 1
    End If
    
    Me.txtEdadActual = edad
End Sub

'==================================================================================================
' PROCEDIMIENTO PRIVADO: CargarRolDesdeCargo
' Función: Carga en txtRol el valor de la columna 2 del combo cmbCargo (campo rol de vista_roles)
'==================================================================================================
Private Sub CargarRolDesdeCargo()
    ' Si no hay cargo seleccionado, limpiar txtRol
    If IsNull(Me.cmbCargo) Or Me.cmbCargo = "" Then
        Me.txtRol = Null
        Exit Sub
    End If
    
    ' Column(2) = tercera columna de vista_roles => campo rol
    Me.txtRol = Me.cmbCargo.Column(2)
End Sub

'==================================================================================================
' EVENTO: txtFechaNacimiento_AfterUpdate
' Función: Recalcula la edad actual cuando se modifica la fecha de nacimiento
'==================================================================================================
Private Sub txtFechaNacimiento_AfterUpdate()
    Call CalcularEdadActual
End Sub



