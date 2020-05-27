package src;

import src.Tool;
import tink.Cli;

class Main
{
    static function main()
    {
        final args    = Sys.args();
        final haxelib = Sys.getEnv('HAXELIB_RUN') != null;
        if (haxelib)
        {
            Sys.setCwd(args.pop());
        }

        Cli.process(args, new Tool()).handle(Cli.exit);
    }
}
