
Namespace ted2go


Class BuildError

	Field path:String
	Field line:Int
	Field msg:String
	Field removed:Bool
	
	Method New( path:String,line:Int,msg:String )
		Self.path=path
		Self.line=line
		Self.msg=msg
	End

	Operator<=>:Int( err:BuildError )
		If line<err.line Return -1
		If line>err.line Return 1
		Return 0
	End
	
End

Class BuildActions

	Field buildAndRun:Action
	Field build:Action
	Field semant:Action
	Field buildSettings:Action
	Field nextError:Action
	Field lockBuildFile:Action
	Field updateModules:Action
	Field rebuildModules:Action
	Field moduleManager:Action
	Field rebuildHelp:Action
	
	Field targetMenu:Menu
	
	Field PreBuild:Void()
	
	Method New( docs:DocumentManager,console:Console,debugView:DebugView )
	
		_docs=docs
		_console=console
		_debugView=debugView
		
		_docs.DocumentRemoved+=Lambda( doc:Ted2Document )

			If doc=_locked _locked=Null
		End
		
		buildAndRun=New Action( "Build and run" )
		buildAndRun.Triggered=OnBuildAndRun
		buildAndRun.HotKey=Key.F5

		build=New Action( "Build only" )
		build.Triggered=OnBuild
		build.HotKey=Key.F6
		
		semant=New Action( "Check app" )
		semant.Triggered=OnSemant
		semant.HotKey=Key.F7
		
		buildSettings=New Action( "Target settings" )
		buildSettings.Triggered=OnBuildFileSettings
		
		nextError=New Action( "Next build error" )
		nextError.Triggered=OnNextError
		nextError.HotKey=Key.F4
		
		lockBuildFile=New Action( "Lock build file" )
		lockBuildFile.Triggered=OnLockBuildFile
		lockBuildFile.HotKey=Key.L
		lockBuildFile.HotKeyModifiers=Modifier.Menu
		
		updateModules=New Action( "Update modules" )
		updateModules.Triggered=OnUpdateModules
		updateModules.HotKey=Key.U
		updateModules.HotKeyModifiers=Modifier.Menu
		
		rebuildModules=New Action( "Rebuild modules" )
		rebuildModules.Triggered=OnRebuildModules
		rebuildModules.HotKey=Key.U
		rebuildModules.HotKeyModifiers=Modifier.Menu|Modifier.Shift
		
		moduleManager=New Action( "Module manager" )
		moduleManager.Triggered=OnModuleManager
		
		rebuildHelp=New Action( "Rebuild documentation" )
		rebuildHelp.Triggered=OnRebuildHelp
		
		local group:=New CheckGroup
		_debugConfig=New CheckButton( "Debug",,group )
		_debugConfig.Layout="fill-x"
		_releaseConfig=New CheckButton( "Release",,group )
		_releaseConfig.Layout="fill-x"
		_debugConfig.Clicked+=Lambda()
			_buildConfig="debug"
		End
		_releaseConfig.Clicked+=Lambda()
			_buildConfig="release"
		End
		_buildConfig="debug"

		group=New CheckGroup

		_desktopTarget=New CheckButton( "Desktop",,group )
		_desktopTarget.Layout="fill-x"
		
		_emscriptenTarget=New CheckButton( "Emscripten",,group )
		_emscriptenTarget.Layout="fill-x"
		
		_wasmTarget=New CheckButton( "Wasm",,group )
		_wasmTarget.Layout="fill-x"
		
		_androidTarget=New CheckButton( "Android",,group )
		_androidTarget.Layout="fill-x"
		
		_iosTarget=New CheckButton( "iOS",,group )
		_iosTarget.Layout="fill-x"
		
		targetMenu=New Menu( "Build target..." )
		targetMenu.AddView( _debugConfig )
		targetMenu.AddView( _releaseConfig )
		targetMenu.AddSeparator()
		targetMenu.AddView( _desktopTarget )
		targetMenu.AddView( _emscriptenTarget )
		targetMenu.AddView( _wasmTarget )
		targetMenu.AddView( _androidTarget )
		targetMenu.AddView( _iosTarget )
		targetMenu.AddSeparator()
		targetMenu.AddAction( buildSettings )
		
		'check valid targets...WIP...
		
		_validTargets=EnumValidTargets( _console )
		
		If _validTargets _buildTarget=_validTargets[0].ToLower()
		
		If _validTargets.Contains( "desktop" )
			_desktopTarget.Clicked+=Lambda()
				_buildTarget="desktop"
			End
		Else
			_desktopTarget.Enabled=False
		Endif
		
		If _validTargets.Contains( "emscripten" )
			_emscriptenTarget.Clicked+=Lambda()
				_buildTarget="emscripten"
			End
		Else
			_emscriptenTarget.Enabled=False
		Endif

		If _validTargets.Contains( "wasm" )
			_wasmTarget.Clicked+=Lambda()
				_buildTarget="wasm"
			End
		Else
			_wasmTarget.Enabled=False
		Endif

		If _validTargets.Contains( "android" )
			_androidTarget.Clicked+=Lambda()
				_buildTarget="android"
			End
		Else
			_androidTarget.Enabled=False
		Endif

		If _validTargets.Contains( "ios" )
			_iosTarget.Clicked+=Lambda()
				_buildTarget="ios"
			End
		Else
			_iosTarget.Enabled=False
		Endif
	End
	
	Method SaveState( jobj:JsonObject )
		
		If _locked jobj["lockedDocument"]=New JsonString( _locked.Path )
		
		jobj["buildConfig"]=New JsonString( _buildConfig )
		
		jobj["buildTarget"]=New JsonString( _buildTarget )
	End
		
	Method LoadState( jobj:JsonObject )
	
		If jobj.Contains( "lockedDocument" )
			Local path:=jobj["lockedDocument"].ToString()
			_locked=Cast<CodeDocument>( _docs.FindDocument( path ) )
			If _locked _locked.State="+"
		Endif
		
		If jobj.Contains( "buildConfig" )
			_buildConfig=jobj["buildConfig"].ToString()
			Select _buildConfig
			Case "release"
				_releaseConfig.Checked=True
			Default
				_debugConfig.Checked=True
				_buildConfig="debug"
			End
		Endif
		
		If jobj.Contains( "buildTarget" )
					
			local target:=jobj["buildTarget"].ToString()

			If _validTargets.Contains( target )
			
				 _buildTarget=target
				
				Select _buildTarget
				Case "desktop"
					_desktopTarget.Checked=True
				Case "emscripten"
					_emscriptenTarget.Checked=True
				Case "wasm"
					_wasmTarget.Checked=True
				Case "android"
					_androidTarget.Checked=True
				Case "ios"
					_iosTarget.Checked=True
				End
			
			Endif
			
		Endif
		
	End
	
	Method Update()
	
		While Not _errors.Empty And _errors.First.removed
			_errors.RemoveFirst()
		Wend
	
		Local idle:=Not _console.Running
		Local canbuild:=idle And BuildDoc()<>Null And _buildTarget
		
		build.Enabled=canbuild
		buildAndRun.Enabled=canbuild
		nextError.Enabled=Not _errors.Empty
		updateModules.Enabled=idle
		rebuildModules.Enabled=idle
		rebuildHelp.Enabled=idle
		moduleManager.Enabled=idle
	End

	Private
	
	Field _docs:DocumentManager
	Field _console:Console
	Field _debugView:DebugView
	
	Field _locked:CodeDocument
	
	Field _errors:=New List<BuildError>
	
	Field _buildConfig:String
	Field _buildTarget:String
	
	Field _debugConfig:CheckButton
	Field _releaseConfig:CheckButton
	Field _desktopTarget:CheckButton
	Field _emscriptenTarget:CheckButton
	Field _wasmTarget:CheckButton
	Field _androidTarget:CheckButton
	Field _iosTarget:CheckButton
	
	Field _validTargets:StringStack
	
	Method BuildDoc:CodeDocument()
		
		If Not _locked Return Cast<CodeDocument>( _docs.CurrentDocument )
		
		Return _locked
	End
	
	Method SaveAll:Bool()
	
		For Local doc:=Eachin _docs.OpenDocuments
			If Not doc.Save() Return False
		Next
		
		Return True
	End
	
	Method ClearErrors()
	
		_errors.Clear()
	
		For Local doc:=Eachin _docs.OpenDocuments
			Local mx2Doc:=Cast<CodeDocument>( doc )
			If mx2Doc mx2Doc.Errors.Clear()
		Next

	End

	Method GotoError( err:BuildError )
	
		Local doc:=Cast<CodeDocument>( _docs.OpenDocument( err.path,True ) )
		If Not doc Return
		
		Local tv := doc.TextView
		If Not tv Return
		
		MainWindow.UpdateWindow( False )
		
		tv.GotoLine( err.line )
	End
	
	Method BuildMx2:Bool( cmd:String,progressText:String,run:Bool=True )
	
		ClearErrors()
		
		_console.Clear()
		
		MainWindow.ShowBuildConsole( False )
		
		If Not SaveAll() Return False

		If Not _console.Start( cmd )
			Alert( "Failed to start process: '"+cmd+"'" )
			Return False
		Endif
		
		Local title := run ? "Building" Else "Checking"
		'Local progress:=New ProgressDialog( title,progressText )
		
		'progress.MinSize=New Vec2i( 320,0 )
		
		'Local cancel:=progress.AddAction( "Cancel" )
		
		'cancel.Triggered=Lambda()
		'	_console.Terminate()
		'End
		
		'progress.Open()
		
		MainWindow.ShowStatusBarText( progressText+" ..." )
		MainWindow.ShowStatusBarProgress( _console.Terminate )
		
		Local hasErrors:=False
		
		Repeat
		
			Local stdout:=_console.ReadStdout()
			If Not stdout Exit
			
			If stdout.StartsWith( "Application built:" )

'				_appFile=stdout.Slice( stdout.Find( ":" )+1 ).Trim()
			Else
			
				Local i:=stdout.Find( "] : Error : " )
				If i<>-1
					hasErrors=True
					Local j:=stdout.Find( " [" )
					If j<>-1
						Local path:=stdout.Slice( 0,j )
						Local line:=Int( stdout.Slice( j+2,i ) )-1
						Local msg:=stdout.Slice( i+12 )
						
						Local err:=New BuildError( path,line,msg )
						Local doc:=Cast<CodeDocument>( _docs.OpenDocument( path,False ) )
						
						If doc
							doc.AddError( err )
							If _errors.Empty 
								MainWindow.ShowBuildConsole( True )
								GotoError( err )
							Endif
							_errors.Add( err )
						Endif
						
					Endif
				Endif
				If Not hasErrors
					i=stdout.Find( "Build error: " )
					hasErrors=(i<>-1)
				Endif
				
			Endif
						
			_console.Write( stdout )
		
		Forever
		
		'progress.Close()
		MainWindow.HideStatusBarProgress()
		
		Local status:=hasErrors ? "Process failed. See the build console for details." Else (_console.ExitCode=0 ? "Process finished." Else "Process cancelled.")
		MainWindow.ShowStatusBarText( status )
		
		Return _console.ExitCode=0
	End

	Method BuildModules:Bool( clean:Bool,target:String )
	
		Local msg:=(clean ? "Rebuilding " Else "Updating ")+target
		
		For Local config:=0 Until 2
		
			Local cfg:=(config ? "debug" Else "release")
			
			Local cmd:=MainWindow.Mx2ccPath+" makemods -target="+target
			If clean cmd+=" -clean"
			cmd+=" -config="+cfg
			
			If Not BuildMx2( cmd,msg+" "+cfg+" modules..." ) Return False
		Next
		
		Return True
	End
	
	Method BuildModules:Bool( clean:Bool )
	
		Local targets:=New StringStack
		
		For Local target:=Eachin _validTargets
			targets.Push( target="ios" ? "iOS" Else target.Capitalize() )
		Next

		targets.Push( "All!" )
		targets.Push( "Cancel" )
		
		Local i:=TextDialog.Run( "Build Modules","Select target..",targets.ToArray(),0,targets.Length-1 )
		
		Local result:=True
		
		Select i
		Case targets.Length-1	'Cancel
			Return False
		Case targets.Length-2	'All!
			For Local i:=0 Until targets.Length-2
				If BuildModules( clean,targets[i] ) Continue
				result=False
				Exit
			Next
		Default
			result=BuildModules( clean,targets[i] )
		End
		
		If result
			_console.Write( "~nBuild modules completed successfully!~n" )
		Else
			_console.Write( "~nBuild modules failed.~n" )
		Endif
		
		Return result
	End
	
	Method MakeDocs:Bool()
	
		Return BuildMx2( MainWindow.Mx2ccPath+" makedocs","Rebuilding documentation..." )
	End
	
	Method BuildApp:Bool( config:String,target:String,action:String )
	
		Local buildDoc:=BuildDoc()
		If Not buildDoc Return False
		
		Local product:=BuildProduct.GetBuildProduct( buildDoc.Path,target,False )
		If Not product Return False
		
		Local opts:=product.GetMx2ccOpts()
		
		Local run:=(action="run")
		If run action="build"

		Local cmd:=MainWindow.Mx2ccPath+" makeapp -"+action+" "+opts
		cmd+=" -config="+config
		cmd+=" -target="+target
		cmd+=" ~q"+buildDoc.Path+"~q"
		
		Local title := action="build" ? "Building" Else "Checking"
		Local msg:=title+" "+StripDir( buildDoc.Path )+" for "+target+" "+config
		
		If Not BuildMx2( cmd,msg,run ) Return False
		
		_console.Write("~nDone.")
		
		If Not run Return True
		
		Local exeFile:=product.GetExecutable()
		If Not exeFile Return True
		
		Select target
		Case "desktop"

			_debugView.DebugApp( exeFile,config )

		Case "emscripten","wasm"
		
			Local mserver:=GetEnv( "MX2_MSERVER" )
			If mserver _console.Run( mserver+" ~q"+exeFile+"~q" )
		
		End
		
		Return True
	End
	
	Method OnBuildAndRun()
		
		PreBuild()
		
		If _console.Running Return
	
		BuildApp( _buildConfig,_buildTarget,"run" )
	End
	
	Method OnBuild()
		
		PreBuild()
		
		If _console.Running Return
	
		BuildApp( _buildConfig,_buildTarget,"build" )
	End
	
	Method OnSemant()
	
		If _console.Running Return
	
		BuildApp( _buildConfig,_buildTarget,"semant" )
	End
	
	Method OnNextError()
	
		While Not _errors.Empty And _errors.First.removed
			_errors.RemoveFirst()
		Wend
		
		If _errors.Empty Return
		
		_errors.AddLast( _errors.RemoveFirst() )
			
		GotoError( _errors.First )
	End
	
	Method OnLockBuildFile()
	
		Local doc:=Cast<CodeDocument>( _docs.CurrentDocument )
		If Not doc Return
		
		If _locked _locked.State=""
		
		If doc=_locked
			_locked=Null
			Return
		Endif
		
		_locked=doc
		_locked.State="+"
		
	End
	
	Method OnBuildFileSettings()

		Local buildDoc:=BuildDoc()
		If Not buildDoc Return
		
		local product:=BuildProduct.GetBuildProduct( buildDoc.Path,_buildTarget,True )
	End
	
	Method OnUpdateModules()
	
		If _console.Running Return
	
		BuildModules( False )
	End
	
	Method OnRebuildModules()
	
		If _console.Running Return
	
		BuildModules( True )
	End
	
	Method OnModuleManager()
	
		If _console.Running Return
	
		Local modman:=New ModuleManager( _console )
		
		modman.Open()
	End
	
	Method OnRebuildHelp()
	
		If _console.Running Return
	
		MakeDocs()
		
		MainWindow.UpdateHelpTree()
	End
	
End
