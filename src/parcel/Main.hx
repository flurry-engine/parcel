package parcel;

import tink.Cli;

class Main
{
    static function main()
    {
        Cli.process(Sys.args(), new Parcel()).handle(Cli.exit);
    }
}