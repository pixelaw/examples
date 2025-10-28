use array::{ArrayTrait, SpanTrait};
use orion::numbers::{FP16x16, FixedTrait};
use orion::operators::tensor::{FP16x16Tensor, Tensor, TensorTrait};

fn tensor() -> Tensor<FP16x16> {
    Tensor { shape: array![1].span(), data: array![FP16x16 { mag: 17046, sign: false }].span() }
}
