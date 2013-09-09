module tasel.path ;

struct Path {
       	Path() {}
	Path( string in_path ) {
		_path = in_path ; 
	}

private:
	string _path ;	
}
