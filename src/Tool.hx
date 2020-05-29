import Types;
import GdxParser;
import haxe.io.Path;
import haxe.io.Bytes;
import haxe.ds.ReadOnlyArray;
import haxe.zip.Compress;
import sys.FileSystem;
import sys.io.File;
import format.png.Tools;
import format.png.Reader;
import hxbit.Serializer;
import tink.Cli;
import uk.aidanlee.flurry.api.resources.Resource;

using Lambda;
using Safety;

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

    final tempBase : String;

    final tempAssets : String;

    final tempFonts : String;

    public function new()
    {
        input        = '';
        output       = '';
        glslCompiler = 'glslangValidator';
        hlslCompiler = 'fxc';

        tempBase   = Path.join([ 'bin', 'temp' ]);
        tempAssets = Path.join([ tempBase, 'assets' ]);
        tempFonts  = Path.join([ tempBase, 'fonts' ]);
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
        final project  = parse();
        final baseDir  = Path.directory(input);
        final prepared = new Map<String, Resource>();

        FileSystem.createDirectory(tempAssets);
        FileSystem.createDirectory(tempFonts);

        // These assets are not packed on a per parcel basis, so can be pre-created and stored.

        for (shader in project.assets.shaders)
        {
            prepared[shader.id] = createShader(baseDir, shader);
        }

        for (text in project.assets.texts)
        {
            prepared[text.id] = new TextResource(text.id, File.getContent(Path.join([ baseDir, text.path ])));
        }

        for (bytes in project.assets.bytes)
        {
            prepared[bytes.id] = new BytesResource(bytes.id, File.getBytes(Path.join([ baseDir, bytes.path ])));
        }

        for (font in project.assets.fonts)
        {
            Sys.command('npx', [
                'msdf-bmfont',
                Path.join([ baseDir, font.path ]),
                '-f', 'json',
                '-o', Path.join([ tempFonts, font.id ]),
                '-p', '2',
                '--smart-size',
                '--pot' ]);
        }

        clean(tempAssets);
 
        for (parcel in project.parcels)
        {
            final assets =
                if (parcel.images == null && parcel.sheets == null && parcel.fonts == null)
                    [];
                else
                    packImages(baseDir, parcel, project.assets.images, project.assets.sheets, project.assets.fonts);

            for (id in parcel.texts.or([]))
            {
                if (prepared.exists(id))
                {
                    assets.push(prepared[id]);
                }
            }
            for (id in parcel.bytes.or([]))
            {
                if (prepared.exists(id))
                {
                    assets.push(prepared[id]);
                }
            }
            for (id in parcel.shaders.or([]))
            {
                if (prepared.exists(id))
                {
                    assets.push(prepared[id]);
                }
            }

            // Serialise and compress the parcel.
            final serializer  = new Serializer();
            final parcel      = new ParcelResource(parcel.name, assets, parcel.depends);
            final bytes       = serializer.serialize(parcel);

            File.saveBytes(Path.join([ output, parcel.name ]), Compress.run(bytes, 9));

            clean(tempAssets);
        }

        clean(tempFonts);

        FileSystem.deleteDirectory(tempAssets);
        FileSystem.deleteDirectory(tempFonts);
        FileSystem.deleteDirectory(tempBase);
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
     * @param _baseDir Base directory to prepend to asset paths
     * @param _shader Info for the shader to create.
     */
    function createShader(_baseDir : String, _shader : JsonShaderResource) : ShaderResource
    {
        final shaderDefinition : JsonShaderDefinition = tink.Json.parse(File.getContent(Path.join([ _baseDir, _shader.path ])));

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
                File.getBytes(Path.join([ _baseDir, _shader.ogl3.vertex ])),
                File.getBytes(Path.join([ _baseDir, _shader.ogl3.fragment ])));
        }
        if (_shader.ogl4 != null)
        {
            if (_shader.ogl4.compiled)
            {
                ogl4Source = ogl4Compile(
                    Path.join([ _baseDir, _shader.ogl4.vertex ]),
                    Path.join([ _baseDir, _shader.ogl4.fragment ]));
            }
            else
            {
                ogl4Source = new ShaderSource(
                    false,
                    File.getBytes(Path.join([ _baseDir, _shader.ogl4.vertex ])),
                    File.getBytes(Path.join([ _baseDir, _shader.ogl4.fragment ])));
            }
        }
        if (_shader.hlsl != null)
        {
            if (_shader.hlsl.compiled)
            {
                hlslSource = hlslCompile(
                    Path.join([ _baseDir, _shader.hlsl.vertex ]),
                    Path.join([ _baseDir, _shader.hlsl.fragment ]));
            }
            else
            {
                hlslSource = new ShaderSource(
                    false,
                    File.getBytes(Path.join([ _baseDir, _shader.hlsl.vertex ])),
                    File.getBytes(Path.join([ _baseDir, _shader.hlsl.fragment ])));
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
     * Pack all image related resources in the parcel and create frame resources for them.
     * @param _baseDir Base directory to prepend to asset paths
     * @param _parcel The parcel to pack.
     * @param _images All image resources in this project.
     * @param _sheets All image sheet resources in this project.
     * @param _fonts All font resources in this project.
     * @return Array<Resource>
     */
    function packImages(_baseDir : String, _parcel : JsonParcel, _images : Array<JsonResource>, _sheets : Array<JsonResource>, _fonts : Array<JsonResource>) : Array<Resource>
    {
        // Parse, store, and copy all images into a temp directory in preperation for packing.

        final atlases = [];
        final bmfonts = [];

        for (id in _parcel.images.or([]))
        {
            _images
                .find(image -> image.id == id)
                .run(image -> File.copy(Path.join([ _baseDir, image.path ]), Path.join([ tempAssets, image.id + '.png' ])));
        }
        for (id in _parcel.sheets.or([]))
        {
            _sheets
                .find(sheet -> sheet.id == id)
                .run(sheet -> {
                    final path  = new Path(Path.join([ _baseDir, sheet.path ]));
                    final atlas = GdxParser.parse(path.toString());

                    for (page in atlas)
                    {
                        File.copy(
                            Path.join([ path.dir, page.image.toString() ]),
                            Path.join([ tempAssets, page.image.toString() ]));
                    }

                    atlases.push(atlas);
                });
        }
        for (id in _parcel.fonts.or([]))
        {
            _fonts
                .find(font -> font.id == id)
                .run(font -> {
                    final path = new Path(font.path);
                    path.dir = tempFonts;
                    path.ext = 'json';

                    final bmfont : JsonFontDefinition = tink.Json.parse(File.getContent(path.toString()));

                    File.copy(
                        Path.join([ tempFonts, bmfont.pages[0] ]),
                        Path.join([ tempAssets, bmfont.pages[0] ]));

                    bmfonts.push(bmfont);
                });
        }

        // Pack all of our collected images

        final packFile = Path.join([ tempAssets, 'pack.json' ]);
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

        File.saveContent(packFile, packJson);

        Sys.command('java', [
            '-jar', Sys.getEnv('GDX_PACKER_JAR'),
            tempAssets,   // input
            tempAssets,   // output
            _parcel.name, // atlas name
            packFile      // atlas settings
        ]);

        // Read the packed result

        final assets = new Array<Resource>();
        final pages  = GdxParser.parse(Path.join([ tempAssets, '${ _parcel.name }.atlas' ]));

        // Create images for all unique pages

        for (page in pages)
        {
            final png = Path.join([ tempAssets, page.image.toString() ]);

            assets.push(new ImageResource(
                page.image.file,
                page.width,
                page.height,
                imageBytes(png)));
        }

        // Search for all of our composited images within the pages

        for (id in _parcel.images.or([]))
        {
            for (page in pages)
            {
                page
                    .sections
                    .find(section -> section.name == id)
                    .run(section -> {
                        assets.push(new ImageFrameResource(
                            id,
                            page.image.file,
                            section.x,
                            section.y,
                            section.width,
                            section.height,
                            section.x / page.width,
                            section.y / page.height,
                            (section.x + section.width) / page.width,
                            (section.y + section.height) / page.height));
                    });
            }
        }

        for (atlas in atlases)
        {
            for (page in atlas)
            {
                final found = findSection(page.image.file, pages).sure();

                for (section in page.sections)
                {
                    assets.push(new ImageFrameResource(
                        section.name,
                        found.page.image.file,
                        found.section.x + section.x,
                        found.section.y + section.y,
                        section.width,
                        section.height,
                        (found.section.x + section.x) / found.page.width,
                        (found.section.y + section.y) / found.page.height,
                        (found.section.x + section.x + section.width) / found.page.width,
                        (found.section.y + section.y + section.height) / found.page.height));
                }

                continue;
            }
        }

        for (bmfont in bmfonts)
        {
            final found = findSection(new Path(bmfont.pages[0]).file, pages).sure();
            final chars = new Map<Int, Character>();

            for (char in bmfont.chars)
            {
                if (char.page == 0)
                {
                    chars[char.id] = new Character(
                        found.section.x + char.x,
                        found.section.y + char.y,
                        char.width,
                        char.height,
                        char.xoffset,
                        char.yoffset,
                        char.xadvance,
                        (found.section.x + char.x) / found.page.width,
                        (found.section.y + char.y) / found.page.height,
                        (found.section.x + char.x + char.width) / found.page.width,
                        (found.section.y + char.y + char.height) / found.page.height);
                }
            }

            assets.push(new FontResource(
                found.section.name,
                found.page.image.file,
                chars,
                found.section.x,
                found.section.y,
                found.section.width,
                found.section.height,
                found.section.x / found.page.width,
                found.section.y / found.page.height,
                (found.section.x + found.section.width) / found.page.width,
                (found.section.y + found.section.height) / found.page.height));

            continue;
        }

        return assets;
    }

    /**
     * Find an atlas section and the page it is within.
     * @param _name Name of the section to search for.
     * @param _pages Structure containing the page and section.
     */
    function findSection(_name : String, _pages : ReadOnlyArray<GdxPage>) : { page : GdxPage, section : GdxSection }
    {
        for (page in _pages)
        {
            final section = page
                .sections
                .find(section -> section.name == _name);

            if (section != null)
            {
                return { page : page, section : section };
            }
        }

        return null;
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
