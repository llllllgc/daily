Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot

function Add-RoundedRectangle {
    param(
        [System.Drawing.Drawing2D.GraphicsPath]$Path,
        [System.Drawing.RectangleF]$Bounds,
        [float]$Radius
    )

    $diameter = $Radius * 2
    $arc = [System.Drawing.RectangleF]::new($Bounds.X, $Bounds.Y, $diameter, $diameter)
    $Path.AddArc($arc, 180, 90)
    $arc.X = $Bounds.Right - $diameter
    $Path.AddArc($arc, 270, 90)
    $arc.Y = $Bounds.Bottom - $diameter
    $Path.AddArc($arc, 0, 90)
    $arc.X = $Bounds.X
    $Path.AddArc($arc, 90, 90)
    $Path.CloseFigure()
}

function New-LauncherIcon {
    param(
        [int]$Size,
        [string]$OutputPath
    )

    $renderSize = $Size * 4
    $bitmap = [System.Drawing.Bitmap]::new(
        $renderSize,
        $renderSize,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.Clear([System.Drawing.Color]::Transparent)

    $scale = $renderSize / 108.0
    $backgroundPath = [System.Drawing.Drawing2D.GraphicsPath]::new()
    Add-RoundedRectangle -Path $backgroundPath -Bounds ([System.Drawing.RectangleF]::new(
        2 * $scale,
        2 * $scale,
        104 * $scale,
        104 * $scale
    )) -Radius (24 * $scale)
    $backgroundBrush = [System.Drawing.SolidBrush]::new(
        [System.Drawing.ColorTranslator]::FromHtml('#F7F6F2')
    )
    $graphics.FillPath($backgroundBrush, $backgroundPath)

    $calendarPath = [System.Drawing.Drawing2D.GraphicsPath]::new()
    Add-RoundedRectangle -Path $calendarPath -Bounds ([System.Drawing.RectangleF]::new(
        25 * $scale,
        39 * $scale,
        58 * $scale,
        44 * $scale
    )) -Radius (9 * $scale)
    $ink = [System.Drawing.ColorTranslator]::FromHtml('#242522')
    $linePen = [System.Drawing.Pen]::new($ink, 5.8 * $scale)
    $linePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $linePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $linePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $graphics.DrawPath($linePen, $calendarPath)
    $graphics.DrawLine($linePen, 38 * $scale, 31 * $scale, 38 * $scale, 45 * $scale)
    $graphics.DrawLine($linePen, 70 * $scale, 31 * $scale, 70 * $scale, 45 * $scale)

    $sageBrush = [System.Drawing.SolidBrush]::new(
        [System.Drawing.ColorTranslator]::FromHtml('#9CA88F')
    )
    $graphics.FillEllipse(
        $sageBrush,
        45 * $scale,
        53 * $scale,
        18 * $scale,
        18 * $scale
    )

    $output = [System.Drawing.Bitmap]::new(
        $Size,
        $Size,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $outputGraphics = [System.Drawing.Graphics]::FromImage($output)
    $outputGraphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $outputGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $outputGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $outputGraphics.DrawImage($bitmap, 0, 0, $Size, $Size)

    $directory = Split-Path -Parent $OutputPath
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }
    $output.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $outputGraphics.Dispose()
    $output.Dispose()
    $sageBrush.Dispose()
    $linePen.Dispose()
    $calendarPath.Dispose()
    $backgroundBrush.Dispose()
    $backgroundPath.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

$targets = @{
    48 = 'android/app/src/main/res/mipmap-mdpi/ic_launcher.png'
    72 = 'android/app/src/main/res/mipmap-hdpi/ic_launcher.png'
    96 = 'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png'
    144 = 'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png'
    192 = 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'
    1024 = 'assets/branding/launcher-source.png'
}

foreach ($entry in $targets.GetEnumerator()) {
    New-LauncherIcon -Size $entry.Key -OutputPath (Join-Path $projectRoot $entry.Value)
}
