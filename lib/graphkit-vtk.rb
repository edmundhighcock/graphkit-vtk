require 'rubypython'

class GraphKit
	class VTKObjectGroup

		def initialize
			@other_objects = {}
		end
		#The Python vtk module
		attr_accessor :vtk_module
		
		# The VTK object which reads the file
		attr_accessor :reader
	 
		# The output of the Reader
		attr_accessor	:output

		# The VTK mapper (which converts the data to image data)
		attr_accessor :mapper

		# The vtkActor which is responsible for the data 
		# within the window
		attr_accessor :actor
		
		# The vtkVolume which is responsible for the data 
		# within the window in the case of volume
		# rendering
		attr_accessor :volume

		# The VTK renderer which renders the image data
		attr_accessor :renderer

		# The VTK object which connects to the renderer
		# and should be connected to an image writer to 
		# write image files. 
		attr_accessor :large_image_renderer

		# The VTK window object into which the data is rendered
		# It is what causes the renderer to act.
		attr_accessor :renderer_window

		# The VTK interactor
		attr_accessor :interactor

		# A hash containing other VTK objects
		attr_reader :other_objects

		def delete
			#([@reader, @mapper, @actor, @volume, @renderer, @renderer_window, @large_image_renderer, @interactor] + other_objects.values).each do |obj|
				#next unless obj
				#begin
					#obj.Delete
				#rescue NoMethodError => err
					#puts err, obj
					#next
				#end
			#end
		end
		

	end
	
	# This module contains methods for rendering GraphKits
	# using the Visualization Toolkit (VTK). It uses the 
	# Python interface to VTK via the RubyPython bridge
	# (see rubygems.org/gems/rubypython).
	#
	# It should work with vtk and vtk-python installed
	# on any Linux distro. 
	#
	# If you want to use it on a supercomputer you will
	# almost certainly have to build Python and VTK yourself.
	#
	# The instructions below have been tested on Hector but
	# can be easily adapted to work anywhere. 
	#
	# First you need to configure your system to use the GNU
	# compilers and with dynamic linking enabled. The instructions
	# for configuring your system for installing CodeRunner should
	# work well. See the CodeRunner wiki (coderunner.sourceforge.net).
	#
	# Choose a directory to install everything: <tt>myprefix</tt>.
	#
	# Download the source for Python 2.x (2.7 works as of Dec 2012),
	# extract it and build it (with shared libraries) as follows.
	#   $ cd Python-2.7.3
	#   $ ./configure  --prefix=<myprefix> --enable-shared LDFLAGS="-Wl,-rpath <myprefix/lib"
	#   $ make && make install
	#
	# Download the VTK source (tested with VTK 5.10) and extract it.
	#
	# Make a directory at the same level as the VTK source folder, 
	# e.g. VTK-bin. Make sure CMake is available (e.g. module load CMake).
	# Configure like this:
	# 	1. $ cd VTK-bin
	# 	2. $ ccmake -i ../VTK5.10.1   # (replace with appropriate folder)
	#
	# You will now enter the CMake interactive configuration. Press 'c' to 
	# run the initial configuration. Press 't' to get to the advanced options.
	# Make sure the settings below are as follows
	# 	CMAKE_INSTALL_PREFIX <myprefix>
	# 	VTK_WRAP_PYTHON on
	#		VTK_USE_RENDERING on
	# 	VTK_USE_X off
	#		VTK_OPENGL_HAS_OSMESA on
	#
	#	The last two settings mean that VTK won't try to pop up windows when 
	#	it is rendering: instead it will write them straight to file. 
	#	OSMESA stands for Off Screen Mesa, where Mesa is the open source
	#	graphics library. 
	#
	#	Press 'c' to update the configuration. 
	#	Now update the following settings:
	#		PYTHON_EXECUTABLE <myprefix>/bin/python
	#		PYTHON_INCLUDE_DIR <myprefix>/include/python2.x
	#		PYTHON_LIBRARY <myprefix>/lib/libpython2.x.so
	#		VTK_USE_OFFSCREEN on
	#		
	#
	# Here is the funky bit: we don't want to use the standard hardware-enabled
	# OpenGL libraries because we want to render offscreen. The standard OpenGL
	# conflicts with OSMESA and makes SEGFAULTS (yuk). Instead we can have OSMESA
	# replace all their functionality by setting
	# 	OPENGL_glu_LIBRARY
	# 	OPENGL_gl_LIBRARY
	# to the same value as
	# 	OSMESA_LIBRARY
	#
	# This will of course not be as fast, but that's OK because we are going
	# to parallelise over the supercomputer when we write our rendering scripts!
	#
	# Press 'c' to configure once more, and 'g' to generate the makefiles.
	# Now build
	# 	$ make     # This will take about 40 mins.
	# 	$ make install
	#
	# Finally we need to setup python: add these lines to your .bashrc
	# 	export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:<myprefix>/lib/vtk-5.10/
	# 	export PYTHONPATH=$PYTHONPATH:<myprefix>/lib/python2.7/site-packages/
	# 	export PATH=<myprefix>/bin:$PATH
	module VTK
	
	# This method returns a VTKObjectGroup object, which 
	# contains references to the VTK/Python objects 
	# which are necessary to plot the graph. 
	def vtk_object_group(filename = nil)
		# If we are not given a filename, need to write the
		# data in VTK format... can change at some point? 
		temp_write = false
		unless filename
			temp_write = true
			filename = (Time.now.to_i).to_s +  $$.to_s + rand(1000000).to_s + ".tmp.vtk"
			to_vtk_legacy_fast(file_name: filename)
		end

		vtk_og = VTKObjectGroup.new
		vtk  = vtk_og.vtk_module = RubyPython.import('vtk')
		file_name = filename

		vtk_og.reader = reader = vtk.vtkUnstructuredGridReader
		reader.SetFileName(file_name)
		reader.Update

		if temp_write
			FileUtils.rm(filename)
		end

		vtk_og.output = output = reader.GetOutput
		scalar_range = output.GetScalarRange

		vtk_og.mapper = mapper = vtk.vtkDataSetMapper
		mapper.SetInput(output)
		mapper.SetScalarRange(scalar_range)

		look_up_table = vtk.vtkLookupTable
		look_up_table.SetNumberOfColors(64)
		look_up_table.SetHueRange(0.0, 0.667)
		mapper.SetLookupTable(look_up_table)
		mapper.SetScalarModeToDefault
		#mapper.CreateDefaultLookupTable
		mapper.ScalarVisibilityOn
		#mapper.SelectColorArray('myvals')


		vtk_og.actor = actor = vtk.vtkActor
		actor.SetMapper(mapper)
		actor.VisibilityOn

		vtk_og.renderer = renderer = vtk.vtkRenderer
		renderer.AddActor(actor)
		#renderer.SetBackground(0,0,0)

		vtk_og.renderer_window = renderer_window = vtk.vtkRenderWindow
		renderer_window.SetSize(640,480)
		renderer_window.AddRenderer(renderer)

		render_large = vtk_og.large_image_renderer =  vtk.vtkRenderLargeImage
		render_large.SetInput(vtk_og.renderer)
		render_large.SetMagnification(4)

		vtk_og.interactor =  interactor = vtk.vtkRenderWindowInteractor
		interactor.SetRenderWindow(renderer_window)
		interactor.Initialize
		#interactor.Start

		return vtk_og
	end

	# Visualise the Graph using the Visualization Toolkit (VTK).
	# If <tt>output_file</tt> is "window", display it in a window;
	# otherwise, write to the file, e.g. my_graph.jpg, my_graph.gif
	# If input_file is given it sould be a VTK data file. Otherwise
	# it will write the data to a temporary VTK legacy data file.
	#
	# The optional block yields a VTKObjectGroup which contains references 
	# to all the VTK objects for arbitrary manipulation before
	# rendering.
	
	def vtk_render(output_file='window', input_file=nil, &block)
		#RubyPython.start
		vtk_og = vtk_object_group(filename)
		yield(vtk_og) if block
		write_file(output_file, vtk_og)
		#vtk = vtk_og.vtk_module
		##filter = vtk.vtkWindowToImageFilter 
		##vtk_og.renderer_window.SetOffScreenRendering(1)
		##gf = vtk.vtkGraphicsFactory
		##gf.SetOffScreenOnlyMode(1)
		#vtk_og.renderer_window.Start
		##vtk_og.reader.Update
		##vtk_og.renderer.Update
		##filter.SetInput(vtk_og.renderer_window)
		###########case File.extname(output_file)
		###########when '.jpeg', '.jpg'
			###########jpeg_writer = vtk.vtkJPEGWriter
			############vtk_og.renderer.DeviceRender
			############jpeg_writer.SetInput(vtk_og.renderer.GetOutput)
			############jpeg_writer.SetInput(render_large.GetOutput)
			###########jpeg_writer.SetInput(vtk_og.large_image_renderer.GetOutput)
			############filter.Update
			###########jpeg_writer.SetFileName(output_file)
			###########jpeg_writer.Write
		###########end
		#vtk_og.renderer_window.Finalize
		#RubyPython.stop

	end


	# This method returns a VTKObjectGroup object, which 
	# contains references to the VTK/Python objects 
	# which are necessary to plot a graph using 
	# volume rendering. 
	#
	# function can be :raycast or :tetrahedra
	#
	def vtk_volume_object_group( function = :raycast, filename = nil, options={})
		# If we are not given a filename, need to write the
		# data in VTK format... can change at some point? 
		temp_write = false
		unless filename
			temp_write = true
			filename = (Time.now.to_i).to_s + $$.to_s + rand(1000000).to_s + ".tmp.vtk"
			to_vtk_legacy_fast(file_name: filename)
		end

		#require 'rubypython'
		#RubyPython.start
		vtk_og = VTKObjectGroup.new
		vtk  = vtk_og.vtk_module = RubyPython.import('vtk')
		file_name = filename

		vtk_og.reader = reader = vtk.vtkUnstructuredGridReader
		reader.SetFileName(file_name)
		reader.Update

		if temp_write
			FileUtils.rm(filename)
		end

		vtk_og.output = output = reader.GetOutput
		ep 'scalar_range', scalar_range = output.GetScalarRange
		#
		
		tf = vtk_og.other_objects[:tetrahedra_filter] = vtk.vtkDataSetTriangleFilter
		tf.SetInput(output)
		

		volprop = vtk_og.other_objects[:volume_property]= vtk.vtkVolumeProperty
		coltranfunc = vtk_og.other_objects[:color_transfer_function] = vtk.vtkColorTransferFunction
		opacfunc = vtk_og.other_objects[:opacity_function] = vtk.vtkPiecewiseFunction

		min, max = scalar_range.to_a
		ep scalar_range.to_a
		max = max.to_s.to_f
		min = min.to_s.to_f
		range = (max-min)
		if options[:cut_range_factor]
		min = min + range/2.0*options[:cut_range_factor]
		max = max - range/2.0*options[:cut_range_factor] 
		end
		ep 'max', max, max.class, 'min', min, min.class

		coltranfunc.AddRGBPoint(min, 0.0, 0.0, 1.0)
		coltranfunc.AddRGBPoint(min + 1.0*(max-min)/5.0, 0.0, 1.0, 1.0)
		coltranfunc.AddRGBPoint(min + 2.0*(max-min)/5.0, 1.0, 0.0, 0.0)
		coltranfunc.AddRGBPoint(min + 3.0*(max-min)/5.0, 1.0, 1.0, 0.0)
		coltranfunc.AddRGBPoint(min + 4.0*(max-min)/5.0, 0.0, 1.0, 0.0)
		coltranfunc.AddRGBPoint(min + 5.0*(max-min)/5.0, 1.0, 1.0, 1.0)

		opacfunc.AddPoint(min, 1)
		opacfunc.AddPoint(max, 1)

		volprop.SetColor(coltranfunc)
		volprop.SetScalarOpacity(opacfunc)


		case function
		when :raycast
			ep "RAYCAST"
			vtk_og.mapper = mapper = vtk.vtkUnstructuredGridVolumeRayCastMapper
			mapper.SetInput(tf.GetOutput)
			mapper.SetRayCastFunction(vtk.vtkUnstructuredGridBunykRayCastFunction)
		when :zsweep
			vtk_og.mapper = mapper = vtk.vtkUnstructuredGridVolumeZSweepMapper
			mapper.SetInput(tf.GetOutput)
			mapper.SetRayIntegrator(vtk.vtkUnstructuredGridHomogeneousRayIntegrator )
		when :tetrahedra
			vtk_og.mapper = mapper = vtk.vtkProjectedTetrahedraMapper
			mapper.SetInput(tf.GetOutput)
			#mapper.SetRayCastFunction(vtk.vtkUnstructuredGridBunykRayCastFunction)
		end
		#mapper.SetScalarRange(scalar_range)

		#look_up_table = vtk.vtkLookupTable
		#look_up_table.SetNumberOfColors(64)
		#look_up_table.SetHueRange(0.0, 0.667)
		#mapper.SetLookupTable(look_up_table)
		mapper.SetScalarModeToDefault
		#mapper.CreateDefaultLookupTable
		#mapper.ScalarVisibilityOn
		#mapper.SelectColorArray('myvals')


		vtk_og.volume = volume = vtk.vtkVolume
		volume.SetMapper(mapper)
		volume.SetProperty(volprop)
		volume.VisibilityOn

		vtk_og.renderer = renderer = vtk.vtkRenderer
		renderer.AddVolume(volume)
		#renderer.SetBackground(0,0,0)

		vtk_og.renderer_window = renderer_window = vtk.vtkRenderWindow
		renderer_window.SetSize(640,480)
		renderer_window.AddRenderer(renderer)

		render_large = vtk_og.large_image_renderer =  vtk.vtkRenderLargeImage
		render_large.SetInput(vtk_og.renderer)
		render_large.SetMagnification(4)

		vtk_og.interactor =  interactor = vtk.vtkRenderWindowInteractor
		interactor.SetRenderWindow(renderer_window)
		interactor.Initialize
		#interactor.Start

		return vtk_og
	end

	# Visualise the GraphKit using the Visualization Toolkit (VTK)
	# volume rendering classes. 
	# If <tt>output_file</tt> is "window", display it in a window;
	# otherwise, write to the file, e.g. my_graph.jpg, my_graph.gif.
	# The 'window' option will not work where VTK has been compiled
	# for off screen rendering only. 
	#
	# If input_file is given it sould be a VTK data file. Otherwise
	# it will write the data to a temporary VTK legacy data file.
	#
	# The optional block yields a VTKObjectGroup which contains references 
	# to all the VTK objects for arbitrary manipulation before
	# rendering.
 
#puts 'LOADING'	
	def vtk_render_volume(output_file='window', function = :raycast, input_file=nil, &block)
		puts 'HERE'
		vtk_og = vtk_volume_object_group(function, filename)
		yield(vtk_og) if block
		write_file(output_file, vtk_og)
		#vtk_og.delete
	end

	def write_file(output_file, vtk_og)
		vtk = vtk_og.vtk_module
		#filter = vtk.vtkWindowToImageFilter 
		#vtk_og.renderer_window.SetOffScreenRendering(1)
		#gf = vtk.vtkGraphicsFactory
		#gf.SetOffScreenOnlyMode(1)
		vtk_og.renderer_window.Start
		#vtk_og.reader.Update
		#vtk_og.renderer.Update
		#filter.SetInput(vtk_og.renderer_window)
		case File.extname(output_file)
		when '.jpeg', '.jpg'
			jpeg_writer = vtk.vtkJPEGWriter
			#vtk_og.renderer.DeviceRender
			#jpeg_writer.SetInput(vtk_og.renderer.GetOutput)
			#jpeg_writer.SetInput(render_large.GetOutput)
			jpeg_writer.SetInput(vtk_og.large_image_renderer.GetOutput)
			#filter.Update
			jpeg_writer.SetFileName(output_file)
			jpeg_writer.Write
		when '.gif'
			gif_writer = vtk.vtkGIFWriter
			gif_writer.SetInput(vtk_og.large_image_renderer.GetOutput)
			gif_writer.SetFileName(output_file)
			gif_writer.Write
		when '.tiff'
			tiff_writer = vtk.vtkTIFFWriter
			tiff_writer.SetInput(vtk_og.large_image_renderer.GetOutput)
			tiff_writer.SetFileName(output_file)
			tiff_writer.Write
		else
			raise 'Cannot write files of this type: ' + output_file
		end
		vtk_og.renderer_window.Finalize
	end


	end #module VTK

	include VTK





end
