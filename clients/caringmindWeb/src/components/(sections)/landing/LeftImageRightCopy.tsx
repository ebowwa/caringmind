/**
 * This code was generated by v0 by Vercel.
 * @see https://v0.dev/t/yaiH5cPpAGU
 */

// src/components/LeftImageRightCopy.tsx
import Image from 'next/image';

type LeftImageRightCopyContent = {
  badge: string;
  title: string;
  description: string;
  imageBucketId: string;
  imagePath: string;
  imageAlt: string;
};

const content: LeftImageRightCopyContent = {
  badge: "New Features",
  title: "Generate product details with ease.",
  description: "Turn your ideas into professional product listings. Our platform makes it simple to create compelling descriptions and eye-catching images for your print-on-demand products.",
  imageBucketId: "static",
  imagePath: "/ui/merchondemandlogo.png", // Update the path to point to the public directory
  imageAlt: "Avatar",
};

export function LeftImageRightCopy() {
  return (
    <section className="w-full py-12 md:py-24 lg:py-32">
      <div className="container px-4 md:px-6">
        <div className="grid gap-6 lg:grid-cols-[1fr_500px] lg:gap-12 xl:grid-cols-[1fr_550px]">
          <Image
            src={content.imagePath}
            alt={content.imageAlt}
            className="mx-auto aspect-video overflow-hidden rounded-xl object-cover object-center sm:w-full"
            width={550} // Set appropriate width
            height={300} // Set appropriate height
          />
          <div className="flex flex-col justify-center space-y-4">
            <div className="space-y-2">
              <div className="inline-block rounded-lg bg-gray-100 px-3 py-1 text-sm dark:bg-gray-800">
                {content.badge}
              </div>
              <h1 className="text-3xl font-bold tracking-tighter sm:text-5xl">
                {content.title}
              </h1>
              <p className="max-w-[600px] text-gray-500 md:text-xl/relaxed lg:text-base/relaxed xl:text-xl/relaxed dark:text-gray-400">
                {content.description}
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}