/* Copyright 2013, Garbanzo Prime

    This file is part of tasel.
    tasel is subject to the license specified in LICENSE.txt
*/
module tasel.ext.filesystem ;

import std.file ;
import std.stdio ;
import tasel.tasel ;

class CopyFile : UserTask {
	this( string src_file , string dst_file ) {
		super( FileRes( src_file ) , FileRes( dst_file ) ) ;
	}

	override bool run() immutable {
		writeln( "copying " ~ inputs[0].name ~ " to " ~ outputs[0].name ) ;
		copy( inputs[0].name , outputs[0].name ) ;
		return true ;
	}
}