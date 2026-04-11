import fs from 'fs';
import svg2img from 'svg2img';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

svg2img(path.join(__dirname, 'public', 'logo.svg'), {width: 512, height: 512}, function(error, buffer) {
    if (error) {
        console.error(error);
        process.exit(1);
    }
    fs.writeFileSync(path.join(__dirname, 'public', 'logo.png'), buffer);
    console.log("Converted successfully!");
});
