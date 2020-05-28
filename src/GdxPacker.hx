package src;

import src.Types.JsonFontDefinition;
import src.GdxParser.GdxSection;
import src.GdxParser.GdxPage;
import format.png.Reader;
import format.png.Tools;
import haxe.io.Path;
import haxe.io.Bytes;
import haxe.ds.ReadOnlyArray;
import sys.io.File;
import uk.aidanlee.flurry.api.resources.Resource;

using StringTools;

enum SearchResult
{
    Sheet(_page : GdxPage);
    Font(_font : JsonFontDefinition);
    Error;
}

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
        "maxWidth": 2048,
        "maxHeight": 2048,
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

    /**
     * Create a new instance which can pack a directory of images.
     * @param _directory Directory to pack.
     * @param _name Name of the generated atlas.
     */
    public function new(_directory : String, _name : String)
    {
        directory = _directory;
        name      = _name;
    }

    /**
     * Generate an atlas file and png (s) from the temp directory.
     * Output atlas and png (s) are also placed in the temp directory.
     */
    public function pack()
    {
        final packFile = Path.join([ directory, 'pack.json' ]);

        File.saveContent(packFile, packJson);

        Sys.command('java', [ '-jar', 'C:/Users/AidanLee/Documents/atlas-test/runnable-texturepacker.jar', directory, directory, name, packFile ]);
    }

    /**
     * Create `ImageResource` and `ImageFrameResource`'s from the generated atlas.
     * We iterate over all the sections in each generated page to try and find all sheets which were added.
     * This is needed to generate the correct UV coorinates.
     * @param _sheets Array of all sheets and the path to them.
     * @return Array<Resource>
     */
    public function resources() : Array<Resource>
    {
        final pages  = GdxParser.parse(Path.join([ directory, '$name.atlas' ]));
        final assets = new Array<Resource>();

        for (page in pages)
        {
            assets.push(new ImageResource(page.image.file, page.width, page.height, imageBytes(Path.join([ directory, page.image.toString() ]))));

            for (section in page.sections)
            {
                // switch findPage(section, _sheets, _fonts)
                // {
                //     case Sheet(_page):
                //         for (subSection in _page.sections)
                //         {
                //             final x = section.x + subSection.x;
                //             final y = section.y + subSection.y;

                //             assets.push(new ImageFrameResource(
                //                 subSection.name,
                //                 page.image.file,
                //                 x,
                //                 y,
                //                 subSection.width,
                //                 subSection.height,
                //                 x / page.width,
                //                 y / page.height,
                //                 (x + subSection.width) / page.width,
                //                 (y + subSection.height) / page.height));
                //         }
                //     case Font(_font):
                //         final chars = new Map<Int, Character>();

                //         for (char in _font.chars)
                //         {
                //             if (char.page == 0)
                //             {
                //                 chars[char.id] = new Character(
                //                     section.x + char.x,
                //                     section.y + char.y,
                //                     char.width,
                //                     char.height,
                //                     char.xoffset,
                //                     char.yoffset,
                //                     char.xadvance,
                //                     (section.x + char.x) / page.width,
                //                     (section.y + char.y) / page.height,
                //                     (section.x + char.x + char.width) / page.width,
                //                     (section.y + char.y + char.height) / page.height);
                //             }
                //         }

                //         assets.push(new FontResource(
                //             section.name,
                //             page.image.file,
                //             chars,
                //             section.x,
                //             section.y,
                //             section.width,
                //             section.height,
                //             section.x / page.width,
                //             section.y / page.height,
                //             (section.x + section.width) / page.width,
                //             (section.y + section.height) / page.height));
                //     case Error:
                //         assets.push(new ImageFrameResource(
                //             section.name,
                //             page.image.file,
                //             section.x,
                //             section.y,
                //             section.width,
                //             section.height,
                //             section.x / page.width,
                //             section.y / page.height,
                //             (section.x + section.width) / page.width,
                //             (section.y + section.height) / page.height));
                // }
            }
        }

        return assets;
    }

    /**
     * Get the BGRA bytes data of a png.
     * @param _path Path to the image.
     * @return Bytes
     */
    function imageBytes(_path : String) : Bytes
    {
        final input = File.read(_path);
        final info  = new Reader(input).read();
        final bytes = Tools.extract32(info);

        input.close();

        return bytes;
    }
}
