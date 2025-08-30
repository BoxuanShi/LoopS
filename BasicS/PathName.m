PathName;

ClearAll[PathName]
PathName[file_String] := DirectoryName[FileNameJoin[{file, "1"}]]