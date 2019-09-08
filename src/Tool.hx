import tink.Cli;
import haxe.zip.Compress;
import haxe.Serializer;
import sys.FileSystem;
import haxe.io.Path;
import sys.io.File;
import json2object.JsonParser;
import format.png.Tools;
import format.png.Reader;
import uk.aidanlee.flurry.api.resources.Resource;
import uk.aidanlee.flurry.api.resources.Parcel.ShaderInfo;
import uk.aidanlee.flurry.api.resources.Parcel.ShaderInfoLayout;
import uk.aidanlee.flurry.api.resources.Parcel.ParcelList;

typedef AssetsInfo = {
    /**
     * All the assets which will be process in the post build step.
     */
    final assets : ParcelList;

    /**
     * All the parcels which will be created in the post build step.
     */
    final parcels : Array<ParcelDefinition>;
}

typedef ParcelDefinition = {
    /**
     * Parcel name.
     */
    final name : String;

    /**
     * IDs of all the assets to be included in this parcel.
     */
    final assets : Array<String>;

    /**
     * Name of all other parcels this parcel depends on.
     */
    final depends : Array<String>;
}

class Tool
{
    final temp = '.temp';

    public var input : String;

    public var output : String;

    public function new()
    {
        //
    }

    @:defaultCommand
    public function help()
    {
        Sys.println('TODO : implement help function');
    }

    @:command
    public function pack()
    {
        final assets   = parse();
        final prepared = new Map<String, Resource>();

        FileSystem.createDirectory(temp);

        for (shader in assets.assets.shaders)
        {
            prepared[shader.id] = createShader(shader);
        }

        for (image in assets.assets.images)
        {
            var input = File.read(image.path);

            var info = new Reader(input).read();
            var head = Tools.getHeader(info);

            prepared[image.id] = new ImageResource(image.id, head.width, head.height, Tools.extract32(info));

            input.close();
        }

        for (text in assets.assets.texts)
        {
            prepared[text.id] = new TextResource(text.id, File.getContent(text.path));
        }

        for (bytes in assets.assets.bytes)
        {
            prepared[bytes.id] = new BytesResource(bytes.id, File.getBytes(bytes.path));
        }

        FileSystem.deleteDirectory(temp);

        for (parcel in assets.parcels)
        {
            var saver = new Serializer();
            saver.serialize(new ParcelResource(parcel.name, [ for (id in parcel.assets) prepared[id] ], parcel.depends));

            File.saveBytes(
                Path.join([ output, parcel.name ]),
                Compress.run(haxe.io.Bytes.ofString(saver.toString()), 9));

            Sys.println('created ${parcel.name}');
        }
    }

    @:command
    public function peek()
    {
        Sys.println('TODO : implement peek function');
    }

    function parse() : AssetsInfo
    {
        var parser = new JsonParser<AssetsInfo>();
        parser.fromJson(File.getContent(input));

        for (error in parser.errors)
        {
            throw error;
        }

        return parser.value;
    }

    /**
     * Creates a shader resource based on the provided info.
     * @param _shader Info for the shader to create.
     */
    function createShader(_shader : ShaderInfo) : ShaderResource
    {
        var parser = new JsonParser<ShaderInfoLayout>();
        parser.fromJson(File.getContent(_shader.path));

        for (error in parser.errors)
        {
            throw error;
        }

        var layout = new ShaderLayout(
            parser.value.textures,
            [
                for (b in parser.value.blocks) new ShaderBlock(b.name, b.binding, [
                    for (v in b.values) new ShaderValue(v.name, v.type)
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
        Sys.command('glslangValidator', [ '-G', '-S', 'vert', _vert, '-o', Path.join([ temp, 'vert.out' ]) ]);
        Sys.command('glslangValidator', [ '-G', '-S', 'frag', _frag, '-o', Path.join([ temp, 'frag.out' ]) ]);

        return new ShaderSource(
            true,
            File.getBytes(Path.join([ temp, 'vert.out' ])),
            File.getBytes(Path.join([ temp, 'frag.out' ])));
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

        Sys.command('fxc', [ '/T', 'vs_5_0', '/E', 'VShader', '/Fo', Path.join([ temp, 'vert.out' ]), _vert ]);
        Sys.command('fxc', [ '/T', 'ps_5_0', '/E', 'PShader', '/Fo', Path.join([ temp, 'frag.out' ]), _frag ]);

        return new ShaderSource(
            true,
            File.getBytes(Path.join([ temp, 'vert.out' ])),
            File.getBytes(Path.join([ temp, 'frag.out' ])));
    }
}
