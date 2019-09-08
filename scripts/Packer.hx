
import hxbit.Serializer;
import sys.io.File;
import hxp.Log;
import hxp.System;
import hxp.Path;
import hxp.Script;
import format.png.Tools;
import format.png.Reader;
import json2object.JsonParser;
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

class Packer extends Script
{
    final temp = '.temp';

    final inputFile : String;

    final outputDirectory : String;

    final assets : AssetsInfo;

    final prepared : Map<String, Resource>;

    final parcels : Array<String>;

    public function new()
    {
        super();

        inputFile       = options.get('input').pop();
        outputDirectory = options.get('output').pop();

        assets   = parse();
        prepared = [];
        parcels  = [];

        build();
        pack();
    }

    function parse() : AssetsInfo
    {
        var parser = new JsonParser<AssetsInfo>();
        parser.fromJson(File.getContent(Path.combine(workingDirectory, inputFile)));

        for (error in parser.errors)
        {
            throw error;
        }

        return parser.value;
    }

    function build()
    {
        System.makeDirectory(Path.combine(workingDirectory, temp));

        for (shader in assets.assets.shaders)
        {
            createShader(shader);
        }

        for (image in assets.assets.images)
        {
            var input = File.read(Path.combine(workingDirectory, image.path));

            var info = new Reader(input).read();
            var head = Tools.getHeader(info);

            prepared[image.id] = new ImageResource(image.id, head.width, head.height, Tools.extract32(info));

            input.close();
        }

        for (text in assets.assets.texts)
        {
            prepared[text.id] = new TextResource(text.id, File.getContent(Path.combine(workingDirectory, text.path)));
        }

        for (bytes in assets.assets.bytes)
        {
            prepared[bytes.id] = new BytesResource(bytes.id, File.getBytes(Path.combine(workingDirectory, bytes.path)));
        }

        for (json in assets.assets.jsons)
        {
            prepared[json.id] = new JsonResource(json.id, haxe.Json.parse(File.getContent(Path.combine(workingDirectory, json.path))));
        }

        System.removeDirectory(Path.combine(workingDirectory, temp));
    }

    /**
     * Creates a shader resource based on the provided info.
     * @param _shader Info for the shader to create.
     */
    function createShader(_shader : ShaderInfo)
    {
        var parser = new JsonParser<ShaderInfoLayout>();
        parser.fromJson(File.getContent(Path.combine(workingDirectory, _shader.path)));

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
                File.getBytes(Path.combine(workingDirectory, _shader.ogl3.vertex)),
                File.getBytes(Path.combine(workingDirectory, _shader.ogl3.fragment)));
        }
        if (_shader.ogl4 != null)
        {
            if (_shader.ogl4.compiled)
            {
                ogl4Source = ogl4Compile(
                    Path.combine(workingDirectory, _shader.ogl4.vertex),
                    Path.combine(workingDirectory, _shader.ogl4.fragment));
            }
            else
            {
                ogl4Source = new ShaderSource(
                    false,
                    File.getBytes(Path.combine(workingDirectory, _shader.ogl4.vertex)),
                    File.getBytes(Path.combine(workingDirectory, _shader.ogl4.fragment)));
            }
        }
        if (_shader.hlsl != null)
        {
            if (_shader.hlsl.compiled)
            {
                hlslSource = hlslCompile(
                    Path.combine(workingDirectory, _shader.hlsl.vertex),
                    Path.combine(workingDirectory, _shader.hlsl.fragment));
            }
            else
            {
                hlslSource = new ShaderSource(
                    false,
                    File.getBytes(Path.combine(workingDirectory, _shader.hlsl.vertex)),
                    File.getBytes(Path.combine(workingDirectory, _shader.hlsl.fragment)));
            }
        }

        prepared[_shader.id] = new ShaderResource(_shader.id, layout, ogl3Source, ogl4Source, hlslSource);
    }

    /**
     * Call glslangValidator and compile a glsl file to spirv.
     * @param _vert Path to the glsl vertex source.
     * @param _frag Path to the glsl fragment source.
     * @return ShaderSource object containing compiled spirv bytes.
     */
    function ogl4Compile(_vert : String, _frag : String) : Null<ShaderSource>
    {
        System.runCommand('', 'glslangValidator', [ '-G', '-S', 'vert', _vert, '-o', Path.join([ workingDirectory, temp, 'vert.out' ]) ]);
        System.runCommand('', 'glslangValidator', [ '-G', '-S', 'frag', _frag, '-o', Path.join([ workingDirectory, temp, 'frag.out' ]) ]);

        return new ShaderSource(
            true,
            File.getBytes(Path.join([ workingDirectory, temp, 'vert.out' ])),
            File.getBytes(Path.join([ workingDirectory, temp, 'frag.out' ])));
    }

    /**
     * Call fxc.exe and compile a hlsl file to a compiled shader object.
     * @param _vert Path to the hlsl vertex source.
     * @param _frag Path to the hlsl fragment source.
     * @return Null<ShaderSource>
     */
    function hlslCompile(_vert : String, _frag : String) : Null<ShaderSource>
    {
        if (System.hostPlatform != WINDOWS)
        {
            Log.info('Cannot compile HLSL shaders on non-windows platforms');
            Log.info('    Creating un-compiled hlsl shader source');

            return new ShaderSource(
                false,
                File.getBytes(Path.combine(workingDirectory, _vert)),
                File.getBytes(Path.combine(workingDirectory, _frag)));
        }

        System.runCommand('', 'fxc', [ '/T', 'vs_5_0', '/E', 'VShader', '/Fo', Path.join([ workingDirectory, temp, 'vert.out' ]), _vert ]);
        System.runCommand('', 'fxc', [ '/T', 'ps_5_0', '/E', 'PShader', '/Fo', Path.join([ workingDirectory, temp, 'frag.out' ]), _frag ]);

        return new ShaderSource(
            true,
            File.getBytes(Path.join([ workingDirectory, temp, 'vert.out' ])),
            File.getBytes(Path.join([ workingDirectory, temp, 'frag.out' ])));
    }

    function pack()
    {
        for (parcel in assets.parcels)
        {
            var saver = new Serializer();
            var bytes = saver.serialize(new ParcelResource(parcel.name, [ for (id in parcel.assets) prepared[id] ], parcel.depends));

            File.saveBytes(Path.join([ workingDirectory, outputDirectory, '${parcel.name}.parcel' ]), bytes);

            Log.info('created parcel "${parcel.name}"');
        }
    }
}
