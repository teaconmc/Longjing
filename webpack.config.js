const path = require('path')
const webpack = require('webpack')

const mode = process.env.NODE_ENV || 'production'

module.exports = {
  output: {
    filename: `worker.${mode}.js`,
    path: path.join(__dirname, 'dist'),
  },
  mode,
  resolve: {
    extensions: ['.ts', '.tsx', '.js'],
    plugins: [],
  },
  plugins: [
    new webpack.DefinePlugin({
      TEACON_BOT_APP_ID: JSON.stringify(process.env.TEACON_BOT_APP_ID),
      TEACON_BOT_PRIVATE_KEY: JSON.stringify(process.env.TEACON_BOT_PRIVATE_KEY),
    }),
  ],
  module: {
    rules: [
      {
        test: /\.tsx?$/,
        loader: 'ts-loader',
        options: {
          transpileOnly: true,
        },
      },
    ],
  },
}
