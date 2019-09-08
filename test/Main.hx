package;

import haxe.Unserializer;
import sys.io.abstractions.mock.MockFileSystem;
import sys.io.abstractions.mock.MockFileData;
import uk.aidanlee.flurry.api.resources.Resource;
import uk.aidanlee.flurry.api.resources.Parcel.ParcelData;
import parcel.Parcel;
import buddy.SingleSuite;

using buddy.Should;

class Main extends SingleSuite
{
    public function new()
    {
        describe('Creating a parcel', {
            
            it('can add text files to a parcel with explicit paths',{
                var files = [
                    'assets.json' => MockFileData.fromText('{ "texts" : [ { "id" : "logo", "path" : "logo.txt" } ] }'),
                    'logo.txt' => MockFileData.fromText('hello world')
                ];

                var parcel = new Parcel(new MockFileSystem(files, []));
                parcel.json = 'assets.json';
                parcel.create();

                var content  = extractParcel(files.get('output.parcel'));

                content[0].should.beType(TextResource);
                cast(content[0], TextResource).id.should.be('logo');
                cast(content[0], TextResource).content.should.be('hello world');
            });

            it('can add text files to a parcel with implicit paths',{
                var files = [
                    'assets.json' => MockFileData.fromText('{ "texts" : [ { "id" : "logo.txt" } ] }'),
                    'logo.txt' => MockFileData.fromText('hello world')
                ];

                var parcel = new Parcel(new MockFileSystem(files, []));
                parcel.json = 'assets.json';
                parcel.create();

                var content  = extractParcel(files.get('output.parcel'));

                content[0].should.beType(TextResource);
                cast(content[0], TextResource).id.should.be('logo.txt');
                cast(content[0], TextResource).content.should.be('hello world');
            });

            it('can add binary files to a parcel with explicit paths',{
                var files = [
                    'assets.json' => MockFileData.fromText('{ "bytes" : [ { "id" : "logo", "path" : "logo.bin" } ] }'),
                    'logo.bin' => MockFileData.fromText('hello world')
                ];

                var parcel = new Parcel(new MockFileSystem(files, []));
                parcel.json = 'assets.json';
                parcel.create();

                var content  = extractParcel(files.get('output.parcel'));

                content[0].should.beType(BytesResource);
                cast(content[0], BytesResource).id.should.be('logo');
                cast(content[0], BytesResource).bytes.toString().should.be('hello world');
            });

            it('can add binary files to a parcel with implicit paths',{
                var files = [
                    'assets.json' => MockFileData.fromText('{ "bytes" : [ { "id" : "logo.bin" } ] }'),
                    'logo.bin' => MockFileData.fromText('hello world')
                ];

                var parcel = new Parcel(new MockFileSystem(files, []));
                parcel.json = 'assets.json';
                parcel.create();

                var content  = extractParcel(files.get('output.parcel'));

                content[0].should.beType(BytesResource);
                cast(content[0], BytesResource).id.should.be('logo.bin');
                cast(content[0], BytesResource).bytes.toString().should.be('hello world');
            });

            it('can add json files to a parcel with explicit paths',{
                //
            });

            it('can add json files to a parcel with implicit paths',{
                //
            });

            it('can add images to a parcel with explicit paths',{
                //
            });

            it('can add images to a parcel with implicit paths',{
                //
            });

            it('can add other parcels to the parcel', {
                //
            });

            describe('Adding shaders', {
                
                it('can add GLSL source files', {
                    //
                });

                it('can add HLSL source files', {
                    //
                });

                it('can add GLSL ES source files', {
                    //
                });

            });

        });
    }

    inline function extractParcel(_file : MockFileData) : Array<Resource>
    {
        var data : ParcelData = Unserializer.run(_file.text);

        var bytes = data.serializedArray;
        if (data.compressed)
        {
            bytes = haxe.zip.Uncompress.run(data.serializedArray);
        }

        return Unserializer.run(bytes.toString());
    }
}
