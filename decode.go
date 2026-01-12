package main

import (
	"fmt"
	"image"
	"image/color"
	_ "image/jpeg"
	_ "image/png"
	"os"
)

func main() {
	file, err := os.Open("input.png")
	if err != nil {
		panic(err)
	}
	defer file.Close()

	img, _, err := image.Decode(file)
	if err != nil {
		panic(err)
	}

	bounds := img.Bounds()
	w, h := bounds.Dx(), bounds.Dy()

	gray := make([]uint8, w*h)

	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			c := color.GrayModel.Convert(img.At(x, y)).(color.Gray)
			gray[y*w+x] = c.Y
		}
	}

	fmt.Println("Loaded image:", w, "x", h)
	fmt.Println("First 16 grayscale values:", gray[:16])

	outputFile, err := os.Open("out.bruh")
	if err != nil {
		if os.IsNotExist(err) {
			outputFile, err = os.Create("out.bruh")
			if err != nil {
				panic(err)
			}
		} else {
			panic(err)
		}
	}
	defer outputFile.Close()

	outputFile.Write([]byte{byte(w >> 0), byte(w >> 8), byte(w >> 16), byte(w >> 24)})
	outputFile.Write([]byte{byte(h >> 0), byte(h >> 8), byte(h >> 16), byte(h >> 24)})
	outputFile.Write(gray)
}
