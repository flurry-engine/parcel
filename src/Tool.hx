package src;

import src.GdxParser;
import src.GdxPacker;
import src.Types;
import haxe.ds.ReadOnlyArray;
import haxe.io.Path;
import haxe.zip.Compress;
import sys.FileSystem;
import sys.io.File;
import hxbit.Serializer;
import tink.Cli;
import uk.aidanlee.flurry.api.resources.Resource;

class Tool
{
    /**
     * Path to the json file describing all assets and parcels.
     * 
     * e.g. `--input=/path/to/some.json`
     */
    public var input : String;

    /**
     * Path to the directory to place all output parcels.
     * 
     * e.g. `--output=/path/to/some/output/directory/`
     */
    public var output : String;

    /**
     * Explicit path to the glsl shader compiler.
     */
    public var glslCompiler : String;

    /**
     * Explicit path to the hlsl shader compiler.
     */
    public var hlslCompiler : String;

    final tempAssets : String;

    final tempFonts : String;

    public function new()
    {
        input        = '';
        output       = '';
        glslCompiler = 'glslangValidator';
        hlslCompiler = 'fxc';

        final baseTemp = Path.join([ 'bin', 'temp' ]);
        tempAssets = Path.join([ baseTemp, 'assets' ]);
        tempFonts  = Path.join([ baseTemp, 'fonts' ]);
    }

    @:defaultCommand
    public function defaultCommand()
    {
        help();
    }

    /**
     * Prints this help text.
     */
    @:command
    public function help()
    {
        Sys.println(Cli.getDoc(this));
    }

    /**
     * Creates the parcels defined in the `input` asset file and places them in the `output` directory.
     */
    @:command
    public function pack()
    {
        final assets   = parse();
        final prepared = new Map<String, Resource>();

        FileSystem.createDirectory(tempAssets);
        FileSystem.createDirectory(tempFonts);

        // These assets are not packed on a per parcel basis, so can be pre-created and stored.

        for (shader in assets.assets.shaders)
        {
            prepared[shader.id] = createShader(shader);
        }

        for (text in assets.assets.texts)
        {
            prepared[text.id] = new TextResource(text.id, File.getContent(text.path));
        }

        for (bytes in assets.assets.bytes)
        {
            prepared[bytes.id] = new BytesResource(bytes.id, File.getBytes(bytes.path));
        }

        for (font in assets.assets.fonts)
        {
            Sys.command('npx', [
                'msdf-bmfont',
                font.path,
                '-f', 'json',
                '-o', Path.join([ tempFonts, '${ new Path(font.path).file }.json' ]),
                '-p', '2',
                '--smart-size',
                '--pot' ]);
        }

        clean(tempAssets);
 
        for (parcel in assets.parcels)
        {
            // Images and pre-compiled sheets are packed on a per-parcel basis
            // Once the pages have been created we append assets in the parcel which have been pre-created from above.
            final finalAssets = generateAtlas(parcel.name, parcel.assets, assets.assets.images, assets.assets.sheets, assets.assets.fonts);
            for (id in parcel.assets)
            {
                if (prepared.exists(id))
                {
                    finalAssets.push(prepared[id]);
                }
            }

            // Serialise and compress the parcel.
            final serializer  = new Serializer();
            final parcel      = new ParcelResource(parcel.name, finalAssets, parcel.depends);
            final bytes       = serializer.serialize(parcel);

            File.saveBytes(Path.join([ output, parcel.name ]), Compress.run(bytes, 9));

            // clean(tempAssets);
        }

        // clean(tempFonts);

        // FileSystem.deleteDirectory(tempAssets);
        // FileSystem.deleteDirectory(tempFonts);
    }

    /**
     * Extracts all assets found in the `input` parcel and places them in the `output` directory.
     */
    @:command
    public function peek()
    {
        Sys.println('TODO : implement peek function');
    }

    /**
     * Parse the json file at the input file location.
     * @return AssetsInfo
     */
    function parse() : JsonDefinition
    {
        return tink.Json.parse(File.getContent(input));
    }

    /**
     * Creates a shader resource based on the provided info.
     * @param _shader Info for the shader to create.
     */
    function createShader(_shader : JsonShaderResource) : ShaderResource
    {
        final shaderDefinition : JsonShaderDefinition = tink.Json.parse(File.getContent(_shader.path));

        final layout = new ShaderLayout(
            shaderDefinition.textures, [
                for (block in shaderDefinition.blocks)
                    new ShaderBlock(block.name, block.binding, [
                        for (value in block.values) new ShaderValue(value.name, value.type)
                    ])
            ]);
        var ogl3Source : Null<ShaderSource> = null;
        var ogl4Source : Null<ShaderSource> = null;
        var hlslSource : Null<ShaderSource> = null;

        if (_shader.ogl3 != null)
        {
            ogl3Source = new ShaderSource(
                false,
                File.getBytes(_shader.ogl3.vertex),
                File.getBytes(_shader.ogl3.fragment));
        }
        if (_shader.ogl4 != null)
        {
            if (_shader.ogl4.compiled)
            {
                ogl4Source = ogl4Compile(_shader.ogl4.vertex, _shader.ogl4.fragment);
            }
            else
            {
                ogl4Source = new ShaderSource(false, File.getBytes(_shader.ogl4.vertex), File.getBytes(_shader.ogl4.fragment));
            }
        }
        if (_shader.hlsl != null)
        {
            if (_shader.hlsl.compiled)
            {
                hlslSource = hlslCompile(_shader.hlsl.vertex,_shader.hlsl.fragment);
            }
            else
            {
                hlslSource = new ShaderSource(false, File.getBytes(_shader.hlsl.vertex), File.getBytes(_shader.hlsl.fragment));
            }
        }

        return new ShaderResource(_shader.id, layout, ogl3Source, ogl4Source, hlslSource);
    }

    /**
     * Call glslangValidator and compile a glsl file to spirv.
     * @param _vert Path to the glsl vertex source.
     * @param _frag Path to the glsl fragment source.
     * @return ShaderSource object containing compiled spirv bytes.
     */
    function ogl4Compile(_vert : String, _frag : String) : Null<ShaderSource>
    {
        Sys.command(glslCompiler, [ '-G', '-S', 'vert', _vert, '-o', Path.join([ tempAssets, 'vert.out' ]) ]);
        Sys.command(glslCompiler, [ '-G', '-S', 'frag', _frag, '-o', Path.join([ tempAssets, 'frag.out' ]) ]);

        return new ShaderSource(
            true,
            File.getBytes(Path.join([ tempAssets, 'vert.out' ])),
            File.getBytes(Path.join([ tempAssets, 'frag.out' ])));
    }

    /**
     * Call fxc.exe and compile a hlsl file to a compiled shader object.
     * @param _vert Path to the hlsl vertex source.
     * @param _frag Path to the hlsl fragment source.
     * @return Null<ShaderSource>
     */
    function hlslCompile(_vert : String, _frag : String) : Null<ShaderSource>
    {
        if (Sys.systemName() != 'Windows')
        {
            Sys.println('Cannot compile HLSL shaders on non-windows platforms');
            Sys.println('    Creating un-compiled hlsl shader source');

            return new ShaderSource(
                false,
                File.getBytes(_vert),
                File.getBytes(_frag));
        }

        Sys.command(hlslCompiler, [ '/T', 'vs_5_0', '/E', 'VShader', '/Fo', Path.join([ tempAssets, 'vert.out' ]), _vert ]);
        Sys.command(hlslCompiler, [ '/T', 'ps_5_0', '/E', 'PShader', '/Fo', Path.join([ tempAssets, 'frag.out' ]), _frag ]);

        return new ShaderSource(
            true,
            File.getBytes(Path.join([ tempAssets, 'vert.out' ])),
            File.getBytes(Path.join([ tempAssets, 'frag.out' ])));
    }

    /**
     * Finds all images and pre-calculated sprite sheets and packs them all together.
     * @param _name Name of the parcel.
     * @param _assets All the resources (including non image and sheet) to be included in the parcel.
     * @param _images All image resources tracked in this project.
     * @param _sheets All sheet resources tracked in this project.
     */
    function generateAtlas(
        _name : String,
        _assets : Array<String>,
        _images : Array<JsonResource>,
        _sheets : Array<JsonResource>,
        _fonts : Array<JsonResource>) : Array<Resource>
    {
        // Iterate over all assets to be included in this parcel and try and find a matching image or sheet ID.
        // There's almost certainly a better way to deal with this, with many assets and parcels this looping could be quite slow.

        final parcelImages = [];
        final parcelSheets = new Array<{ path : Path, pages : ReadOnlyArray<GdxPage> }>();
        final parcelFonts  = new Array<{ path : Path, font : JsonFontDefinition }>();

        for (asset in _assets)
        {
            for (image in _images)
            {
                if (asset == image.id)
                {
                    parcelImages.push(image);
                }
            }
            for (sheet in _sheets)
            {
                if (asset == sheet.id)
                {
                    parcelSheets.push({ path : new Path(sheet.path), pages : GdxParser.parse(sheet.path) });
                }
            }
            for (font in _fonts)
            {
                if (asset == font.id)
                {
                    final path = new Path(font.path);
                    final json = Path.join([ tempFonts, '${ path.file }.json' ]);

                    parcelFonts.push({ path : path, font : tink.Json.parse(File.getContent(json)) });
                }
            }
        }

        if (parcelImages.length == 0 && parcelSheets.length == 0 && parcelFonts.length == 0)
        {
            return [];
        }

        // Copy all the images to a temp location

        for (image in parcelImages)
        {
            File.copy(image.path, Path.withExtension(Path.join([ tempAssets, image.id ]), 'png'));
        }
        for (sheets in parcelSheets)
        {
            for (page in sheets.pages)
            {
                File.copy(Path.join([ sheets.path.dir, page.image.toString() ]), Path.join([ tempAssets, page.image.toString() ]));
            }
        }
        for (font in parcelFonts)
        {
            for (page in font.font.pages)
            {
                File.copy(Path.join([ tempFonts, page ]), Path.join([ tempAssets, page ]));
            }
        }

        // Pack all the images which have been copied over to the temp directory.
        final packer = new GdxPacker(tempAssets, _name);
        packer.pack();

        // Create resources from the packed images.
        return packer.resources(parcelSheets, parcelFonts);
    }

    /**
     * Remove an entire directory.
     * @param _dir Directory to remove.
     */
    function clean(_dir : String)
    {
        for (item in FileSystem.readDirectory(_dir))
        {
            var path = Path.join([ _dir, item ]);
            
            if (FileSystem.isDirectory(path))
            {
                clean(path);
            }
            else
            {
                FileSystem.deleteFile(path);
            }
        }
    }
}
