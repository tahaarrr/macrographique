import os
from PIL import Image

logo_path = r'c:\Users\Eskander\Desktop\rapport_essai_app\logo + icon\logo.png'
logo = Image.open(logo_path).convert('RGBA')

# Get exact royal blue color from logo
blue_color = (0, 76, 191)

# Master 512x512 icon with solid royal blue background
master = Image.new('RGBA', (512, 512), (0, 76, 191, 255))
w, h = logo.size
scale = min(440 / w, 440 / h)
new_w, new_h = int(w * scale), int(h * scale)
logo_resized = logo.resize((new_w, new_h), Image.Resampling.LANCZOS)
master.paste(logo_resized, ((512 - new_w) // 2, (512 - new_h) // 2), logo_resized)
master_rgb = master.convert('RGB')

# Master foreground for adaptive icon (transparent background)
foreground = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
foreground.paste(logo_resized, ((512 - new_w) // 2, (512 - new_h) // 2), logo_resized)

res_dir = r'c:\Users\Eskander\Desktop\rapport_essai_app\android\app\src\main\res'

sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

fg_sizes = {
    'mipmap-mdpi': 108,
    'mipmap-hdpi': 162,
    'mipmap-xhdpi': 216,
    'mipmap-xxhdpi': 324,
    'mipmap-xxxhdpi': 432,
}

for folder, s in sizes.items():
    t_dir = os.path.join(res_dir, folder)
    os.makedirs(t_dir, exist_ok=True)
    master_rgb.resize((s, s), Image.Resampling.LANCZOS).save(os.path.join(t_dir, 'ic_launcher.png'))
    master_rgb.resize((s, s), Image.Resampling.LANCZOS).save(os.path.join(t_dir, 'ic_launcher_round.png'))
    fg_s = fg_sizes[folder]
    foreground.resize((fg_s, fg_s), Image.Resampling.LANCZOS).save(os.path.join(t_dir, 'ic_launcher_foreground.png'))
    print(f'Generated icons for {folder}')

values_dir = os.path.join(res_dir, 'values')
os.makedirs(values_dir, exist_ok=True)
with open(os.path.join(values_dir, 'colors.xml'), 'w', encoding='utf-8') as f:
    f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#004CBF</color>\n</resources>\n')

v26_dir = os.path.join(res_dir, 'mipmap-anydpi-v26')
os.makedirs(v26_dir, exist_ok=True)
xml_content = '<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n    <background android:drawable="@color/ic_launcher_background" />\n    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n</adaptive-icon>\n'

with open(os.path.join(v26_dir, 'ic_launcher.xml'), 'w', encoding='utf-8') as f:
    f.write(xml_content)

with open(os.path.join(v26_dir, 'ic_launcher_round.xml'), 'w', encoding='utf-8') as f:
    f.write(xml_content)

# Update web icons
web_icons_dir = r'c:\Users\Eskander\Desktop\rapport_essai_app\web\icons'
os.makedirs(web_icons_dir, exist_ok=True)
master_rgb.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, 'Icon-192.png'))
master_rgb.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, 'Icon-512.png'))
master_rgb.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, 'Icon-maskable-192.png'))
master_rgb.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, 'Icon-maskable-512.png'))

# Windows ICO
win_ico_path = r'c:\Users\Eskander\Desktop\rapport_essai_app\windows\runner\resources\app_icon.ico'
master_rgb.save(win_ico_path, format='ICO', sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print('Saved Windows ICO:', win_ico_path)

print('All launcher icons generated successfully from user logo.png!')
