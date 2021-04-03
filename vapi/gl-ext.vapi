namespace GL_EXT {
    [CCode (cheader_filename = "GL/glext.h", cname = "GL_OPTIMAL_TILING_EXT")]
	public const int GL_OPTIMAL_TILING_EXT;
	[CCode (cheader_filename = "GL/glext.h", cname = "GL_TEXTURE_TILING_EXT")]
	public const int GL_TEXTURE_TILING_EXT;
	[CCode (cheader_filename = "GL/glext.h", cname = "GL_DEDICATED_MEMORY_OBJECT_EXT")]
	public const int GL_DEDICATED_MEMORY_OBJECT_EXT;
	[CCode (cheader_filename = "GL/glext.h", cname = "GL_HANDLE_TYPE_OPAQUE_FD_EXT")]
	public const int GL_HANDLE_TYPE_OPAQUE_FD_EXT;
	[CCode (cheader_filename = "GL/glext.h", cname = "glCreateMemoryObjectsEXT")]
	public static void glCreateMemoryObjectsEXT (GL.GLsizei n, out GL.GLuint[]? memoryObjects);
	[CCode (cheader_filename = "GL/glext.h", cname = "glDeleteMemoryObjectsEXT")]
	public static void glDeleteMemoryObjectsEXT (GL.GLsizei n, GL.GLuint[]? memoryObjects);
	[CCode (cheader_filename = "GL/glext.h", cname = "glMemoryObjectParameterivEXT")]
	public static void glMemoryObjectParameterivEXT (GL.GLuint memoryObject, GL.GLenum pname, out GL.GLint[]? params);
	[CCode (cheader_filename = "GL/glext.h", cname = "glGetMemoryObjectParameterivEXT")]
	public static void glGetMemoryObjectParameterivEXT (GL.GLuint memoryObject, GL.GLenum pname, out GL.GLint[]? params);
	[CCode (cheader_filename = "GL/glext.h", cname = "glImportMemoryFdEXT")]
	public static void glImportMemoryFdEXT (GL.GLuint memory, GL.GLuint64 size, GL.GLenum handleType, GL.GLint fd);
	[CCode (cheader_filename = "GL/glext.h", cname = "glTexStorageMem2DEXT")]
	public static void glTexStorageMem2DEXT (GL.GLenum target, GL.GLsizei levels, GL.GLenum internalFormat, GL.GLsizei width, GL.GLsizei height, GL.GLuint memory, GL.GLuint64 offset);
}