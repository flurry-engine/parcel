import GdxParser.GdxSection;
import haxe.ds.ReadOnlyArray;
import GdxParser.GdxPage;
import uk.aidanlee.flurry.api.resources.Resource.ImageResource;
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
    static final packJson = '{
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
        "maxWidth": 512,
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

    public function new(_directory : String, _name : String)
    {
        directory = _directory;
        name      = _name;
    }

    public function pack()
    {
        final packFile = Path.join([ directory, 'pack.json' ]);

        File.saveContent(packFile, packJson);

        Sys.command('java', [ '-jar', 'C:/Users/AidanLee/Documents/atlas-test/runnable-texturepacker.jar', directory, directory, name, packFile ]);
    }

    public function resources(_sheets : Array<{ path : Path, pages : ReadOnlyArray<GdxPage> }>) : Array<Resource>
    {
        final pages  = GdxParser.parse(Path.join([ directory, '$name.atlas' ]));
        final assets = new Array<Resource>();

        for (page in pages)
        {
            assets.push(new ImageResource(page.image.file, page.width, page.height, imageBytes(Path.join([ directory, page.image.toString() ]))));

            for (section in page.sections)
            {
                switch findPage(section, _sheets)
                {
                    case Ok(_page):
                        for (subSection in _page.sections)
                        {
                            final x = section.x + subSection.x;
                            final y = section.y + subSection.y;

                            assets.push(new ImageFrameResource(
                                subSection.name,
                                page.image.file,
                                x,
                                y,
                                subSection.width,
                                subSection.height,
                                x / page.width,
                                y / page.height,
                                (x + subSection.width) / page.width,
                                (y + subSection.height) / page.height));
                        }
                    case Error:
                        assets.push(new ImageFrameResource(
                            section.name,
                            page.image.file,
                            section.x,
                            section.y,
                            section.width,
                            section.height,
                            section.x / page.width,
                            section.y / page.height,
                            (section.x + section.width) / page.width,
                            (section.y + section.height) / page.height));
                }
            }
        }

        return assets;
    }

    function imageBytes(_path : String) : Bytes
    {
        final input = File.read(_path);
        final info  = new Reader(input).read();
        final bytes = Tools.extract32(info);

        input.close();

        return bytes;
    }

    function findPage(_section : GdxSection, _sheets : Array<{ path : Path, pages : ReadOnlyArray<GdxPage> }>) : Result<GdxPage>
    {
        for (sheet in _sheets)
        {
            for (page in sheet.pages)
            {
                if (page.image.file == _section.name)
                {
                    return Ok(page);
                }
            }
        }

        return Error;
    }
}

private class Page
{
    public function new()
    {
        //
    }
}

