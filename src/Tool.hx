import hxp.System;
import hxp.Haxelib;
import hxp.Path;

class Tool
{
    final args : Array<String>;

    static function main()
    {
        new Tool();
    }

    public function new()
    {
        args = Sys.args();

        if (Sys.getEnv('HAXELIB_RUN') == '1')
        {
            if (args.length > 0)
            {
                Sys.setCwd(args.pop());
            }
        }

        switch args.shift()
        {
            case 'pack':
                runHxpScript(Path.join([ Haxelib.getPath(new Haxelib('parcel')), 'scripts', 'Packer.hx' ]));

            case _unknown:
                trace('unknown command $_unknown');
        }
    }

    function runHxpScript(_script : String, _command : String = 'default')
	{	
		final dir  = Path.directory(_script);
		final file = Path.withoutDirectory(_script);

		var className = Path.withoutExtension(file);
		className = className.substr(0, 1).toUpperCase() + className.substr(1);
		
		final version   = '1.1.2';
		final buildArgs = [
			className,
			'-D', 'hxp=$version',
			'-L', 'hxp',
            '-L', 'flurry',
            '-L', 'json2object',
            '-p', Path.combine(Haxelib.getPath(new Haxelib('parcel')), 'scripts')];
		final runArgs = [ 'hxp.Script', _command ].concat(args);
		
		runArgs.push(className);
		runArgs.push(Sys.getCwd());
		
		System.runScript(_script, buildArgs, runArgs, dir);
	}
}
