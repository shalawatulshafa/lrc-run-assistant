const ok = (res, data = {}, status = 200) => {
  return res.status(status).json({
    success: true,
    data: data
  });
};

const fail = (res, code, message, status = 400) => {
  return res.status(status).json({
    success: false,
    error: {
      code: code,
      message: message
    }
  });
};

export { ok, fail };