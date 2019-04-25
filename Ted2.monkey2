
#If __TARGET__="windows"

#Import "bin/wget.exe"

'to build resource.o when icon changes...
'
'windres resource.rc resource.o

#If __ARCH__="x86"
#Import "logo/resource.o"
#Elseif __ARCH__="x64"
#Import "logo/resource_x64.o"
#Endif

'#Endif

'----------------------------

'#Import "<reflection>"

#Import "<std>"
#Import "<mojo>"
#Import "<mojox>"
#Import "<tinyxml2>"
#Import "<sdl2>"
 
#Import "action/FileActions"
#Import "action/EditActions"
#Import "action/BuildActions"
#Import "action/HelpActions"
#Import "action/FindActions"
#Import "action/GotoActions"
#Import "action/WindowActions"
#Import "action/TabActions"
#Import "action/FoldingActions"

#Import "dialog/FindDialog"
#Import "dialog/PrefsDialog"
#Import "dialog/EditProductDialog"
#Import "dialog/DialogExt"
#Import "dialog/NoTitleDialog"
#Import "dialog/FindInFilesDialog"
#Import "dialog/UpdateModulesDialog"
#Import "dialog/GenerateClassDialog"
#Import "dialog/RecentFilesDialog"

#Import "document/DocumentManager"
#Import "document/Ted2Document"
#Import "document/CodeDocument"
#Import "document/PlainTextDocument"
#Import "document/ImageDocument"
#Import "document/AudioDocument"
#Import "document/JsonDocument"
#Import "document/XmlDocument"
#Import "document/BananasDocument"
#Import "document/SceneDocument"

#Import "eventfilter/TextViewKeyEventFilter"
#Import "eventfilter/Monkey2KeyEventFilter"

#Import "parser/CodeItem"
#Import "parser/Parser"
#Import "parser/Monkey2Parser"
#Import "parser/ParserPlugin"
#Import "parser/CodeParsing"

#Import "product/BuildProduct"
#Import "product/Mx2ccEnv"
#Import "product/ModuleManager"

#Import "syntax/Keywords"
#Import "syntax/Monkey2Keywords"
#Import "syntax/Highlighter"
#Import "syntax/Monkey2Highlighter"
#Import "syntax/CppHighlighter"
#Import "syntax/CppKeywords"
#Import "syntax/JavaHighlighter"
#Import "syntax/JavaKeywords"
#Import "syntax/GlslHighlighter"
#Import "syntax/GlslKeywords"
#Import "syntax/CodeFormatter"
#Import "syntax/Monkey2Formatter"

#Import "testing/ParserTests"

#Import "utils/Extensions"
#Import "utils/JsonUtils"
#Import "utils/Utils"
#Import "utils/TextUtils"
#Import "utils/ViewUtils"

#Import "view/CodeMapView"
#Import "view/CodeTextView"
#Import "view/ConsoleViewExt"
#Import "view/ListViewExt"
#Import "view/AutocompleteView"
#Import "view/TreeViewExt"
#Import "view/CodeTreeView"
#Import "view/CodeGutterView"
#Import "view/ToolBarViewExt"
#Import "view/HintView"
#Import "view/HtmlViewExt"
#Import "view/ProjectBrowserView"
#Import "view/TabViewExt"
#Import "view/StatusBarView"
#Import "view/DebugView"
#Import "view/ProjectView"
#Import "view/HelpTreeView"
#Import "view/Ted2TextView"
#Import "view/Ted2CodeTextView"
#Import "view/JsonTreeView"
#Import "view/XmlTreeView"
#Import "view/Monkey2TreeView"
#Import "view/GutterView"
#Import "view/MenuExt"
#Import "view/ScrollableViewExt"
#Import "view/BuildErrorListViewItem"
#Import "view/TextFieldExt"
#Import "view/SpacerView"
#Import "view/FindReplaceView"
#Import "view/ViewExtensions"
#Import "view/DockingViewExt"
#Import "view/DraggableViewListener"
#Import "view/Undock"
#Import "view/TextViewExt"
#Import "view/ExamplesView"

#Import "theme/ThemeImages"
#Import "theme/ThemesInfo"

#Import "ActionsProvider"
#Import "PathsProvider"
#Import "Tree"
#Import "Tuple"
#Import "Plugin"
#Import "Prefs"
#Import "ProcessReader"
#Import "LiveTemplates"
#Import "MainWindow"

#Import "di/Di"
#Import "di/DiSetup"


Namespace ted2go

Using std..
Using mojo..
Using mojox..
Using tinyxml2..
Using sdl2..


Const MONKEY2_DOMAIN:="http://monkeycoder.co.nz"

Global AppTitle:="Ted2Go v2.14a/Ex v0.1"

Function Main()
	
	SetupDiContainer()
	
	Prefs.LoadLocalState()
	
	Local root:=Prefs.MonkeyRootPath
	If Not root Then root=AppDir()
	
	root=SetupMonkeyRootPath( root,True )
	If Not root libc.exit_( 1 )
	
	If root<>Prefs.MonkeyRootPath
		Prefs.MonkeyRootPath=root
		Prefs.SaveLocalState()
	Endif
	
	ChangeDir( root )
	
	'load ted2 state
	'
	Local jobj:=JsonObject.Load( "bin/ted2.state.json" )
	If Not jobj jobj=New JsonObject
	
	Prefs.LoadState( jobj )
	
	ThemesInfo.Load( "theme::themes.json" )
	
	'initial theme
	'
	If Not jobj.Contains( "theme" ) jobj["theme"]=New JsonString( "theme-hollow" )
	
	If Not jobj.Contains( "themeScale" ) jobj["themeScale"]=New JsonNumber( 1 )
	
	SetConfig( "MOJO_INITIAL_THEME",jobj.GetString( "theme" ) )
	
	SetConfig( "MOJO_INITIAL_THEME_SCALE",jobj.GetString( "themeScale" ) )
	
	#If __TARGET__="windows"
	If Prefs.OpenGlProfile
		SetConfig( "MOJO_OPENGL_PROFILE",Prefs.OpenGlProfile )
	Endif
	#Endif
	
	'start the app!
	'
	New AppInstance
	
	InitHotkeys()
	
	'initial window state
	'
	Local flags:=WindowFlags.Resizable|WindowFlags.HighDPI
	
	Local rect:Recti
	
	If jobj.Contains( "windowRect" )
		rect=ToRecti( jobj["windowRect"] )
	Else
		Local w:=Min( 1480,App.DesktopSize.x-40 )
		Local h:=Min( 970,App.DesktopSize.y-64 )
		rect=New Recti( 0,0,w,h )
		flags|=WindowFlags.Center
	Endif
	
	New MainWindowInstance( AppTitle,rect,flags,jobj )
	
	App.Idle+=Lambda()
		
		' open docs from args
		Local args:=AppArgs()
		For Local i:=1 Until args.Length
			Local arg:=args[i]
			arg=arg.Replace( "\","/" )
			MainWindow.OnFileDropped( arg )
		Next
		
		#If __TARGET__="macos"
		App.Idle+=Lambda() ' quick fix for black screen on mojave at startup
			
			Local dx:=MainWindow.Frame.Left Mod 2 = 0 ? -1 Else 1
			MainWindow.Frame=MainWindow.Frame+New Recti( dx,0,0,0 )
			MainWindow.RequestRender()
		End
		#Endif
	End
	
	SDL_EnableScreenSaver()
	
	App.Run()
	
End

Function SetupMonkeyRootPath:String( rootPath:String,searchMode:Bool )
	
#If __DESKTOP_TARGET__
	
	If searchMode
		' search for desired folder
		Local found:=FindBinFolder( rootPath )
		' search for AddDir() folder
		If Not found And rootPath<>AppDir() Then found=FindBinFolder( AppDir() )
		' search for choosen-by-requester folder
		While Not found
			
			Local ok:=Confirm( "Initializing","Monkey2 root directory isn't set.~nTo continue, you should specify it." )
			If Not ok
				Return ""
			End
			Local s:=requesters.RequestDir( "Choose Monkey2 folder",AppDir() )
			found=FindBinFolder( s )
		Wend
		
		rootPath=found
	Else
		
		Local ok:= (GetFileType( "bin" )=FileType.Directory And GetFileType( "modules" )=FileType.Directory)
		If Not ok
			Notify( "Monkey2 root folder","Incorrect folder!" )
			Return ""
		Endif
		
	Endif
	
#Endif
	
	Return rootPath
End

Function GetActionTextWithShortcut:String( action:Action )
	
	Return action.Text+" ("+action.HotKeyText+")"
End

Function Exec( exePath:String,args:String="" )
	
#If __HOSTOS__="windows"
	
	libc.system( exePath+" "+args )
	
#Else If __HOSTOS__="macos"
	
	libc.system( "open ~q"+exePath+"~q --args "+args )
	
#Else If __HOSTOS__="linux"
	
	libc.system( exePath+" "+args+" >/dev/null 2>/dev/null &" )
	
#Else If __HOSTOS__="raspbian"
	
	libc.system( exePath+" "+args+" >/dev/null 2>/dev/null &" )
	
#Endif
	
End


Private

Function FindBinFolder:String( startingFolder:String )
	
	Local cur:=CurrentDir()
	Local ok:=True
	ChangeDir( startingFolder )
	
	While GetFileType( "bin" )<>FileType.Directory Or GetFileType( "modules" )<>FileType.Directory
		
		If IsRootDir( CurrentDir() )
			
			ok=False
			Exit
		Endif
		
		ChangeDir( ExtractDir( CurrentDir() ) )
	Wend
	Local result:=ok ? CurrentDir() Else ""
	ChangeDir( cur )
	
	Return result
End
