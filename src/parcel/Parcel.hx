package parcel;

import haxe.Serializer;
import haxe.Json;
import haxe.io.Bytes;
import format.png.Tools;
import format.png.Reader;
import uk.aidanlee.flurry.api.resources.Resource;
import uk.aidanlee.flurry.api.resources.Parcel.ParcelData;
import uk.aidanlee.flurry.api.resources.Parcel.ShaderInfo;
import uk.aidanlee.flurry.api.resources.Parcel.ImageInfo;
import uk.aidanlee.flurry.api.resources.Parcel.JSONInfo;
import uk.aidanlee.flurry.api.resources.Parcel.TextInfo;
import uk.aidanlee.flurry.api.resources.Parcel.BytesInfo;
import uk.aidanlee.flurry.api.resources.Parcel.ParcelList;
import uk.aidanlee.flurry.api.resources.Parcel.ResourceInfo;
import sys.io.abstractions.concrete.FileSystem;
import sys.io.abstractions.IFileSystem;

using Safety;

/**
 * Capable of creating and extracting binary compressed flurry parcels.
 */
class Parcel
{
    /**
     * Path to a json file containing a list of files to be included in the output parcel.
     */
    @:flag('-from-json')
    public var json : String;

    /**
     * The output parcel file path.
     */
    @:flag('-output')
    public var output : String;

    /**
     * If the parcel should be compressed.
     */
    @:flag('--compress')
    public var compress : Bool;

    /**
     * If hidden files (files beginning with a dot) should be skipped when scanning a directory.
     */
    @:flag('--ignore-hidden')
    public var ignoreHidden : Bool;

    /**
     * Enable displaying debug messages.
     */
    @:flag('--verbose')
    public var verbose : Bool;

    /**
     * Abstracted access to the hard drive for easy testing.
     */
    final fileSystem : IFileSystem;

    public function new(_fileSystem : Null<IFileSystem> = null)
    {
        json         = '';
        output       = 'output.parcel';
        compress     = false;
        ignoreHidden = false;
        verbose      = false;
        fileSystem   = _fileSystem.or(new FileSystem());
    }

    /**
     * Creates a binary packed parcel containing the assets found in a json file.
     * The json file contains the ID of the asset and the path to file the bytes data.
     * These assets are then loaded, serialized, and optionally compressed.
     * The resource system can then load these binary parcels instead of manually specifying the resources found in a parcel.
     * 
     * All path locations provided to this command or found in the json file should be absolute locations or relative to the parcel tool / current directory.
     */
    @:defaultCommand
    public function create()
    {
        var parcel : ParcelList = Json.parse(fileSystem.file.getText(json));

        // Load and create resources for all the requested assets.
        // This chunck of asset loading and resource creation is basically identical to that found in the resource system.
        // Code could probably be shared.

        var resources : Array<Resource> = [];

        var assets : Array<BytesInfo> = parcel.bytes.or([]);
        for (asset in assets)
        {
            resources.push(new BytesResource(asset.id, fileSystem.file.getBytes(getResourceInfoPath(asset))));

            log('Bytes asset "${asset.id}" added');
        }

        var assets : Array<TextInfo> = parcel.texts.or([]);
        for (asset in assets)
        {
            resources.push(new TextResource(asset.id, fileSystem.file.getText(getResourceInfoPath(asset))));

            log('Text asset "${asset.id}" added');
        }

        var assets : Array<JSONInfo> = parcel.jsons.or([]);
        for (asset in assets)
        {
            resources.push(new JSONResource(asset.id, Json.parse(fileSystem.file.getText(getResourceInfoPath(asset)))));

            log('JSON asset "${asset.id}" added');
        }

        var assets : Array<ImageInfo> = parcel.images.or([]);
        for (asset in assets)
        {
            var info = new Reader(fileSystem.file.read(getResourceInfoPath(asset))).read();
            var head = Tools.getHeader(info);

            resources.push(new ImageResource(asset.id, head.width, head.height, Tools.extract32(info).getData()));

            log('Image asset "${asset.id}" added');
        }

        var assets : Array<ShaderInfo> = parcel.shaders.or([]);
        for (asset in assets)
        {
            var layout = Json.parse(fileSystem.file.getText(getResourceInfoPath(asset)));
            var sourceWebGL = asset.ogl3 == null ? null : { vertex : fileSystem.file.getText(asset.ogl3!.vertex.sure()), fragment : fileSystem.file.getText(asset.ogl3!.fragment.sure()) };
            var sourceGL45  = asset.ogl4 == null ? null : { vertex : fileSystem.file.getText(asset.ogl4!.vertex.sure()), fragment : fileSystem.file.getText(asset.ogl4!.fragment.sure()) };
            var sourceHLSL  = asset.hlsl == null ? null : { vertex : fileSystem.file.getText(asset.hlsl!.vertex.sure()), fragment : fileSystem.file.getText(asset.hlsl!.fragment.sure()) };

            resources.push(new ShaderResource(asset.id, layout, sourceWebGL, sourceGL45, sourceHLSL));

            log('Shader asset "${asset.id}" added');
            log('   webgl : ${asset.ogl3 != null}');
            log('   gl45  : ${asset.ogl4 != null}');
            log('   hlsl  : ${asset.hlsl != null}');
        }

        // Serialize the assets array and then optionally compress the bytes.
        // Haxe Compress.run compression is handled by zlib, 9 indicates optimise for size over speed.

        var serializer = new Serializer();
        serializer.serialize(resources);

        var arrayBytes = Bytes.ofString(serializer.toString());
        
        log('Assets array serialized to ${arrayBytes.length} bytes');

        if (compress)
        {
            arrayBytes = haxe.zip.Compress.run(arrayBytes, 9);

            log('Assets array compressed to ${arrayBytes.length} bytes');
        }

        // The actual stored bytes is a ParcelData struct.
        // It contains the resource array bytes and if they have been compressed.

        var parcelBytes : ParcelData = {
            compressed      : compress,
            serializedArray : arrayBytes
        };

        var serializer = new Serializer();
        serializer.serialize(parcelBytes);

        // Write the final bytes to the specified file location.

        fileSystem.file.create(output);
        fileSystem.file.writeBytes(output, Bytes.ofString(serializer.toString()));

        log('Parcel written to $output');
    }

    /**
     * If the resource info path is not defined we assume the id is also the path.
     * @param _resource ResourceInfo to get the path for.
     * @return String
     */
    inline function getResourceInfoPath(_resource : ResourceInfo) : String
    {
        return _resource.path.or(_resource.id);
    }

    /**
     * Print text if the verbose mode is enabled.
     * @param _message Message to print.
     */
    inline function log(_message : String)
    {
        if (verbose)
        {
            Sys.println(_message);
        }
    }
}
