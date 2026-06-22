const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { authMiddleware } = require('../middleware/auth');
const { success, fail } = require('../response');
const logger = require('../logger');

const router = express.Router();
router.use(authMiddleware);

const UPLOAD_DIR = path.join(__dirname, '..', '..', 'uploads');
if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOAD_DIR),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const name = Date.now() + '-' + Math.random().toString(36).substring(2, 8) + ext;
    cb(null, name);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowedExt = /\.(jpg|jpeg|png|gif|webp|mp4|mov|avi)$/i;
    const allowedMime = /^image\/(jpeg|png|gif|webp)$|^video\/(mp4|quicktime|x-msvideo)$/;
    if (!allowedExt.test(path.extname(file.originalname))) {
      return cb(new Error('仅支持 jpg/png/gif/webp/mp4/mov/avi 格式'));
    }
    if (!allowedMime.test(file.mimetype)) {
      return cb(new Error('文件类型不合法'));
    }
    cb(null, true);
  },
});

router.post('/', upload.single('file'), (req, res) => {
  if (!req.file) return fail(res, '请选择文件', 'VALIDATION_ERROR', 400);
  const url = '/uploads/' + req.file.filename;
  success(res, { url, filename: req.file.filename });
});

router.post('/multiple', upload.array('files', 10), (req, res) => {
  if (!req.files || req.files.length === 0) return fail(res, '请选择文件', 'VALIDATION_ERROR', 400);
  const urls = req.files.map(f => ({ url: '/uploads/' + f.filename, filename: f.filename }));
  success(res, { urls });
});

router.use((err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') return fail(res, '文件大小不能超过10MB', 'VALIDATION_ERROR', 400);
    return fail(res, err.message, 'VALIDATION_ERROR', 400);
  }
  if (err) return fail(res, err.message, 'VALIDATION_ERROR', 400);
  next();
});

module.exports = router;
