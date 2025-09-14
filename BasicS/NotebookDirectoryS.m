ClearAll[NotebookDirectoryS];
NotebookDirectoryS[] := 
 DirectoryName[If[$FrontEnd === Null, $InputFileName, NotebookFileName[]]]

$NotebookDirectory = NotebookDirectryS[];