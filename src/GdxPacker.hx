import format.png.Reader;
import format.png.Tools;
import haxe.io.Bytes;
import haxe.io.Eof;
import haxe.io.Input;
import haxe.io.Path;
import sys.io.File;
import sys.io.FileInput;
import uk.aidanlee.flurry.api.resources.Resource;

using StringTools;

class GdxPacker
{
    final packJson = '{
        "pot": true,
        "paddingX": 0,
        "paddingY": 0,
        "bleed": true,
        "bleedIterations": 2,
        "edgePadding": true,
        "duplicatePadding": false,
        "rotation": false,
        "minWidth": 16,
        "minHeight": 16,
        "maxWidth": 256,
        "maxHeight": 512,
        "square": false,
        "stripWhitespaceX": false,
        "stripWhitespaceY": false,
        "alphaThreshold": 0,
        "filterMin": "Nearest",
        "filterMag": "Nearest",
        "wrapX": "ClampToEdge",
        "wrapY": "ClampToEdge",
        "format": "RGBA8888",
        "alias": true,
        "outputFormat": "png",
        "jpegQuality": 0.9,
        "ignoreBlankImages": true,
        "fast": false,
        "debug": false,
        "combineSubdirectories": false,
        "flattenPaths": false,
        "premultiplyAlpha": false,
        "useIndexes": false,
        "limitMemory": true,
        "grid": false,
        "scale": [ 1 ],
        "scaleSuffix": [ "" ],
        "scaleResampling": [ "bicubic" ]
    }';

    final directory : String;

    final name : String;

    final assets : Array<Resource>;

    public function new(_directory : String, _name : String)
    {
        directory = _directory;
        name      = _name;
        assets    = [];
    }

    public function pack()
    {
        final packFile = Path.join([ directory, 'pack.json' ]);

        File.saveContent(packFile, packJson);

        Sys.command('java', [ '-jar', 'C:/Users/AidanLee/Documents/atlas-test/runnable-texturepacker.jar', directory, directory, name, packFile ]);
    }

    public function generate()
    {
        final input  = File.read(Path.join([ directory, 'preload.atlas' ]));

        try
        {
            input.readLine();

            readPages(input);
        }
        catch (_ex : Eof)
        {
            input.close();
        }
    }

    public function resources() return assets;

    function readPages(_input : Input)
    {
        var line = _input.readLine();
        while (line != '')
        {
            // Read header
            final image  = line;
            final size   = _input.readLine();
            final format = _input.readLine();
            final filter = _input.readLine();
            final repeat = _input.readLine();

            final wh   = size.split(':')[1].split(',');
            final page = new ImageResource(
                image.replace('.png', ''),
                Std.parseInt(wh[0]),
                Std.parseInt(wh[1]),
                imageBytes(Path.join([ directory, image ]))); 

            assets.push(page);

            readSections(_input, page.id, page.width, page.height);

            line = _input.readLine();
        }
    }

    function readSections(_input : Input, _page : String, _width : Int, _height : Int)
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
            final u1 = x / _width;
            final v1 = y / _height;
            final u2 = (x + w) / _width;
            final v2 = (y + h) / _height;

            assets.push(new ImageFrameResource(name, _page, x, y, w, h, u1, v1, u2, v2));

            line = _input.readLine();
        }
    }

    function imageBytes(_path : String) : Bytes
    {
        final input = File.read(_path);
        final info  = new Reader(input).read();
        final bytes = Tools.extract32(info);

        input.close();

        return bytes;
    }
}

private class Page
{
    public function new()
    {
        //
    }
}

