package src;

import sys.io.File;
import haxe.io.Path;
import haxe.io.Input;
import haxe.ds.ReadOnlyArray;

class GdxParser
{
    public static function parse(_path : String) : ReadOnlyArray<GdxPage>
    {
        final input = File.read(_path);
        final pages = [];

        readPages(input, pages);

        input.close();

        return pages;
    }

    static function readPages(_input : Input, _output : Array<GdxPage>)
    {
        _input.readLine();

        while (true)
        {
            final image    = _input.readLine();
            final size     = _input.readLine();
            final format   = _input.readLine();
            final filter   = _input.readLine();
            final repeat   = _input.readLine();
            final sections = [];
            final exit     = readSections(_input, sections);

            final wh = size.split(':')[1].split(',');

            _output.push(new GdxPage(
                new Path(image),
                Std.parseInt(wh[0]),
                Std.parseInt(wh[1]),
                sections));

            if (exit)
            {
                return;
            }
        }
    }

    static function readSections(_input : Input, _sections : Array<GdxSection>)
    {
        var line = _input.readLine();
        while (line != '')
        {
            final name     = line;
            final rotated  = _input.readLine();
            final position = _input.readLine();
            final size     = _input.readLine();
            final original = _input.readLine();
            final offset   = _input.readLine();
            final index    = _input.readLine();

            final xy = position.split(':')[1].split(',');
            final wh = size.split(':')[1].split(',');

            final x = Std.parseInt(xy[0]);
            final y = Std.parseInt(xy[1]);
            final w = Std.parseInt(wh[0]);
            final h = Std.parseInt(wh[1]);
            
            _sections.push(new GdxSection(name, x, y, w, h));

            try
            {
                line = _input.readLine();
            }
            catch (_)
            {
                return true;
            }
        }

        return false;
    }
}

class GdxPage
{
    public final image : Path;
    public final width : Int;
    public final height : Int;
    public final sections : ReadOnlyArray<GdxSection>;

    public function new(_image : Path, _width : Int, _height : Int, _sections : ReadOnlyArray<GdxSection>)
    {
        image    = _image;
        width    = _width;
        height   = _height;
        sections = _sections;
    }
}

class GdxSection
{
    public final name : String;
    public final x : Int;
    public final y : Int;
    public final width : Int;
    public final height : Int;

    public function new(_name : String, _x : Int, _y : Int, _width : Int, _height : Int)
    {
        name   = _name;
        x      = _x;
        y      = _y;
        width  = _width;
        height = _height;
    }
}
