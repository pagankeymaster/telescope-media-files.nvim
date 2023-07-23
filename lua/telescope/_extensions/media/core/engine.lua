local M = {}

local Task = require("plenary.job")
local fnamemodify = vim.fn.fnamemodify
local Log = require("telescope._extensions.media.core.log")

---@class MagickOptions
---@field quality string Reduce quality in percentages. Example "20%"
---@field blurred number a blur value between 0.0 and 1.0. Inclusive.
---@field interlace "Line"|"None"|"Partition"|"Plane" see ImageMagick documentation.
---@field frame string frame number. Example: "[0]" i.e. the first frame.

---@class FontMagickOptions
---@field fill string hex color string for the foreground of the rendered image.
---@field background string hex color string for the background of the rendered image.
---@field pointsize string fontsize.
---@field text_lines string[] text to render.

---@class FfmpegOptions
---@field map_start string input_file_index:stream_type_specifier:stream_index
---@field map_finish string same as map_start and see <https://trac.ffmpeg.org/wiki/Map>.
---@field loglevel string|number

---@class FfmpegThumbnailerOptions
---@field size number|string size of the thumbnail. Default: "0".
---@field time string frame to seek. Example: "10%".

---@class PdfToppmOptions
---@field scale_to_x string|number scales each page horizontally to fit in scale-to-x pixels,
---@field scale_to_y string|number scales each page vertically to fit in scale-to-y pixels.
---@field first_page string|number first page to print.
---@field last_page string|number last page to print

---Ready-made task helper function.
---@param options table same as what `Job` uses.
---@return Job
local function primed_task(options)
  local task = Task:new(vim.tbl_extend("keep", options, {
    interactive = false,
    enable_handlers = false,
    enable_recording = false,
  }))

  Log.debug("primed_task(): started a task with command: " .. task.command .. " and args: " .. table.concat(task.args, " "))
  task:start()
  return task
end

---Descaler for images. Including GIF. This reduces quality, adds blur to the image.
---@param input_path string path to the image file.
---@param output_path string path to the descaled image.
---@param options MagickOptions extra options to change the output behavior.
---@param on_exit function to run after the output image has been generated.
---@return Job
function M.magick(input_path, output_path, options, on_exit)
  options = vim.tbl_extend("keep", options, {
    quality = "20%",
    blurred = "0.06",
    interlace = "Plane",
    frame = "[0]",
  })

  return primed_task({
    command = "convert",
    args = {
      "-strip",
      "-interlace",
      options.interlace,
      "-gaussian-blur",
      options.blurred,
      "-quality",
      options.quality,
      input_path .. options.frame,
      output_path,
    },
    on_exit = on_exit,
  })
end

---Renders specified font characters to an image using ImageMagick.
---@param font_path string path to the font file.
---@param output_path string path to where the rendered image will be created.
---@param options FontMagickOptions extra options to change the way the rendered image will be generated.
---@param on_exit function to run after the image has been generated.
---@return Job
function M.fontmagick(font_path, output_path, options, on_exit)
  options = vim.tbl_extend("keep", options, {
    fill = "#000000",
    background = "#FFFFFF",
    pointsize = "100",
    text_lines = {
      vim.fn.fnamemodify(font_path, ":t:r"),
      [[                                                                   ]],
      [[ABC.DEF.GHI.JKL.MNO.PQRS.TUV.WXYZ abc.def.ghi.jkl.mno.pqrs.tuv.wxyz]],
      [[1234567890 ,._-+= >< ¯-¬_ >~–÷+×< {}[]()<>`+-=$*/#_%^@\&|~?'" !,.;:]],
      [[!iIlL17|¦ coO08BbDQ $5SZ2zsz 96G& dbqp E3 g9qCGQ vvwVVW <= != == >=]],
      [[                                                                   ]],
      [[       -<< -< -<- <-- <--- <<- <- -> ->> --> ---> ->- >- >>-       ]],
      [[       =<< =< =<= <== <=== <<= <= => =>> ==> ===> =>= >= >>=       ]],
      [[       <-> <--> <---> <----> <=> <==> <===> <====> :: ::: __       ]],
      [[       <~~ </ </> /> ~~> == != /= ~= <> === !== !=== =/= =!=       ]],
      [[       <: := :- :+ <* <*> *> <| <|> |> <. <.> .> +: -: =: :>       ]],
      [[       (* *) /* */ [| |] {| |} ++ +++ \/ /\ |- -| <!-- <!---       ]],
    },
  })

  return primed_task({
    command = "convert",
    args = {
      "-strip",
      "-size",
      "5000x3000",
      "xc:" .. options.background,
      "-gravity",
      "center",
      "-pointsize",
      options.pointsize,
      "-font",
      font_path,
      "-fill",
      options.fill,
      "-annotate",
      "+0+0",
      table.concat(options.text_lines, "\n"),
      "-flatten",
      output_path,
    },
    on_exit = on_exit,
  })
end

---Extract a frame from a video using ffmpeg.
---@param input_path string path to the video file.
---@param output_path string path to the extracted frame.
---@param options FfmpegOptions extra behavioral options.
---@param on_exit function callback to run after extraction of the frame is complete.
---@return Job
function M.ffmpeg(input_path, output_path, options, on_exit)
  options = vim.tbl_extend("keep", options, {
    map_start = "0:v",
    map_finish = "0:V?",
    loglevel = "8",
  })

  return primed_task({
    command = "ffmpeg",
    args = {
      "-i",
      input_path,
      "-map",
      options.map_start,
      "-map",
      options.map_finish,
      "-c",
      "copy",
      "-v",
      options.loglevel,
      output_path,
    },
    on_exit = on_exit,
  })
end

---Generate a thumbnail from a video file.
---@param input_path string path to the video file.
---@param output_path string generated path to the thumbnail.
---@param options FfmpegThumbnailerOptions extra behavioral options.
---@param on_exit function callback to run after generating the thumbnail image.
---@return Job
function M.ffmpegthumbnailer(input_path, output_path, options, on_exit)
  options = vim.tbl_extend("keep", options, {
    size = "0",
    time = "10%",
  })

  return primed_task({
    command = "ffmpegthumbnailer",
    args = {
      "-i", input_path,
      "-o", output_path,
      "-s", options.size,
      "-t", options.time,
    },
    on_exit = on_exit,
  })
end

---Extract a page from a PDF file as an image.
---@param pdf_path string path to the PDF file.
---@param output_path string path to the extracted image.
---@param options PdfToppmOptions extra options.
---@param on_exit function callback to run after extraction of the page is complete.
---@return Job
function M.pdftoppm(pdf_path, output_path, options, on_exit)
  options = vim.tbl_extend("keep", options, {
    scale_to_x = "-1",
    scale_to_y = "-1",
    first_page = "1",
    last_page = "1",
  })

  return primed_task({
    command = "pdftoppm",
    args = {
      "-f", options.first_page,
      "-l", options.last_page,
      "-scale-to-x", options.scale_to_x,
      "-scale-to-y", options.scale_to_y,
      "-singlefile",
      "-jpeg",
      "-tiffcompression",
      "jpeg",
      pdf_path,
      fnamemodify(output_path, ":r"),
    },
    on_exit = on_exit,
  })
end

---Generate a thumbnail from an EPUB file.
---@param input_path string path to the EPUB file.
---@param output_path string path to the generated thumbnail file.
---@param options {size:string|number} extra options. See `epub-thumbnailer` help page.
---@param on_exit function to run after the thumbnail has been generated.
---@return Job
function M.epubthumbnailer(input_path, output_path, options, on_exit)
  options = vim.tbl_extend("keep", options, { size = "2000" })

  return primed_task({
    command = "epub-thumbnailer",
    args = {
      input_path,
      output_path,
      options.size,
    },
    on_exit = on_exit,
  })
end

---Get cover page of a ebook file.
---@param input_path string path to the ebook.
---@param output_path string path to the extracted cover image of the ebook.
---@param on_exit function to run after the cover has been extracted.
---@return Job
function M.ebookmeta(input_path, output_path, _, on_exit)
  return primed_task({
    command = "ebook-meta",
    args = {
      "--get-cover",
      input_path,
      output_path,
    },
    on_exit = on_exit,
  })
end

---ZIP metadata.
---@param input_path string path to the zip archive.
---@param on_exit function callback that will be called after the zip metadata has been fetched.
---@return Job
function M.zipinfo(input_path, on_exit)
  return primed_task({
    command = "zipinfo",
    args = { "-1", input_path },
    enable_recording = true,
    enable_handlers = true,
    on_exit = on_exit,
  })
end

---Wrapper function for unzipping zip archives.
---@param output_directory string path to output directory.
---@param zip_path string path to the zip archive.
---@param zip_item string extract only one targeted zip member.
---@param on_exit function to run after the zip item has been extracted.
---@return Job
function M.unzip(output_directory, zip_path, zip_item, on_exit)
  return primed_task({
    command = "unzip",
    args = { "-d", output_directory, zip_path, zip_item },
    on_exit = on_exit,
  })
end

return M
